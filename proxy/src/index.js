import { askGemini, createSseParser, textFromRecord } from './gemini.js';
import { LIMITS, sentencePrompt, wordPrompt } from './prompts.js';

/**
 * Bookerize proxy.
 *
 * Its whole job is to hold the Gemini API key. A key compiled into a Flutter app
 * can be pulled out of the IPA in minutes; here it lives in a secret only the
 * Worker can read, and each device carries a token you can revoke on its own.
 *
 *   POST /v1/word     { word, sentence } -> text/event-stream
 *   POST /v1/explain  { sentence }       -> text/event-stream
 *   GET  /health
 *
 * The response stream is deliberately simpler than Gemini's:
 *   data: {"text":"..."}   zero or more
 *   data: {"error":"..."}  on failure, mid-stream included
 *   data: [DONE]           always last
 */
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Use POST.' }, 405);
    }

    const token = bearerToken(request);
    if (!token || !isAllowed(token, env.ALLOWED_TOKENS)) {
      // Deliberately vague: a probing client learns nothing about which half failed.
      return json({ error: 'Not authorised.' }, 401);
    }

    if (env.RATE_LIMITER) {
      const { success } = await env.RATE_LIMITER.limit({ key: token });
      if (!success) {
        return json({ error: 'Slow down a moment and try again.' }, 429);
      }
    }

    if (!env.GEMINI_API_KEY) {
      return json({ error: 'The server is missing its API key.' }, 500);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Expected JSON.' }, 400);
    }

    let prompt;
    if (url.pathname === '/v1/word') {
      const word = clean(body?.word, LIMITS.word);
      const sentence = clean(body?.sentence, LIMITS.sentence);
      if (!word || !sentence) {
        return json({ error: 'Both word and sentence are required.' }, 400);
      }
      prompt = wordPrompt({ word, sentence });
    } else if (url.pathname === '/v1/explain') {
      const sentence = clean(body?.sentence, LIMITS.sentence);
      if (!sentence) return json({ error: 'A sentence is required.' }, 400);
      prompt = sentencePrompt({ sentence });
    } else {
      return json({ error: 'No such endpoint.' }, 404);
    }

    return streamAnswer({ env, prompt, ctx, signal: request.signal });
  },
};

async function streamAnswer({ env, prompt, ctx, signal }) {
  let upstream;
  try {
    upstream = await askGemini({
      apiKey: env.GEMINI_API_KEY,
      model: env.GEMINI_MODEL || 'gemini-3.6-flash',
      system: prompt.system,
      input: prompt.input,
      signal,
    });
  } catch {
    return json({ error: 'Could not reach the model.' }, 502);
  }

  if (!upstream.ok || !upstream.body) {
    // Never pass the upstream body through: it can name the model, the project,
    // and occasionally echo the key's identity.
    return json({ error: `The model refused the request (${upstream.status}).` }, 502);
  }

  const { readable, writable } = new TransformStream();
  ctx.waitUntil(pump(upstream.body, writable));

  return new Response(readable, {
    headers: {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache',
      connection: 'keep-alive',
    },
  });
}

async function pump(source, writable) {
  const writer = writable.getWriter();
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  const parse = createSseParser();
  const reader = source.getReader();

  const send = (payload) => writer.write(encoder.encode(`data: ${payload}\n\n`));

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;

      for (const record of parse(decoder.decode(value, { stream: true }))) {
        const text = textFromRecord(record);
        if (text !== null) await send(JSON.stringify({ text }));
      }
    }
  } catch {
    // The reader may already have sent useful text, so report the failure
    // inside the stream rather than as a status code that never arrives.
    await send(JSON.stringify({ error: 'The answer stopped early.' }));
  } finally {
    await send('[DONE]');
    await writer.close();
  }
}

function bearerToken(request) {
  const header = request.headers.get('authorization') || '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : null;
}

/**
 * Compares against the allow-list without leaking length or position through
 * timing. Small audience, but this is the one door into a paid API.
 */
export function isAllowed(token, allowedTokens) {
  if (!token || !allowedTokens) return false;

  let matched = false;
  for (const candidate of allowedTokens.split(',')) {
    const trimmed = candidate.trim();
    if (trimmed.length > 0 && constantTimeEquals(token, trimmed)) matched = true;
  }
  return matched;
}

function constantTimeEquals(a, b) {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return difference === 0;
}

export function clean(value, maxLength) {
  if (typeof value !== 'string') return null;
  const collapsed = value.replace(/\s+/g, ' ').trim();
  if (collapsed.length === 0) return null;
  return collapsed.slice(0, maxLength);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}
