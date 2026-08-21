import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';

import worker from '../src/index.js';

const realFetch = globalThis.fetch;
afterEach(() => {
  globalThis.fetch = realFetch;
});

/** A stand-in for Gemini that streams the given text deltas back as SSE. */
function fakeGemini(deltas, { ok = true, status = 200 } = {}) {
  return async (url, options) => {
    fakeGemini.lastCall = { url, options, body: JSON.parse(options.body) };
    if (!ok) return new Response('upstream said no', { status });

    const body = [
      'event: interaction.created\ndata: {"interaction":{"id":"v1_a"}}\n\n',
      ...deltas.map(
        (text) =>
          `event: step.delta\ndata: ${JSON.stringify({ delta: { type: 'text', text } })}\n\n`,
      ),
      'event: done\ndata: [DONE]\n\n',
    ].join('');

    return new Response(body, { status: 200, headers: { 'content-type': 'text/event-stream' } });
  };
}

const env = () => ({
  GEMINI_API_KEY: 'test-key',
  GEMINI_MODEL: 'gemini-3.6-flash',
  ALLOWED_TOKENS: 'good-token',
});

const ctx = () => {
  const pending = [];
  return { waitUntil: (p) => pending.push(p), settle: () => Promise.all(pending) };
};

function post(path, body, token = 'good-token') {
  return new Request(`https://proxy.example${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

async function collect(response) {
  const text = await new Response(response.body).text();
  return text
    .split('\n\n')
    .filter((line) => line.startsWith('data: '))
    .map((line) => line.slice(6));
}

test('health needs no token', async () => {
  const request = new Request('https://proxy.example/health');
  const response = await worker.fetch(request, env(), ctx());

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
});

test('a request without a token is refused', async () => {
  const response = await worker.fetch(
    post('/v1/word', { word: 'a', sentence: 'b' }, null),
    env(),
    ctx(),
  );
  assert.equal(response.status, 401);
});

test('a request with the wrong token is refused', async () => {
  const response = await worker.fetch(
    post('/v1/word', { word: 'a', sentence: 'b' }, 'stolen'),
    env(),
    ctx(),
  );
  assert.equal(response.status, 401);
});

test('the refusal does not say which half was wrong', async () => {
  const response = await worker.fetch(post('/v1/word', {}, 'stolen'), env(), ctx());
  const body = await response.json();

  assert.equal(body.error, 'Not authorised.');
  assert.doesNotMatch(JSON.stringify(body), /token|key|allow/i);
});

test('rate limiting refuses politely', async () => {
  const limited = { ...env(), RATE_LIMITER: { limit: async () => ({ success: false }) } };
  const response = await worker.fetch(
    post('/v1/word', { word: 'a', sentence: 'b' }),
    limited,
    ctx(),
  );

  assert.equal(response.status, 429);
  assert.match((await response.json()).error, /Slow down/);
});

test('rate limiting is keyed by token, not by IP', async () => {
  let seenKey = null;
  const limited = {
    ...env(),
    RATE_LIMITER: {
      limit: async ({ key }) => {
        seenKey = key;
        return { success: true };
      },
    },
  };
  globalThis.fetch = fakeGemini(['ok']);

  const context = ctx();
  const response = await worker.fetch(post('/v1/word', { word: 'a', sentence: 'b' }), limited, context);
  await collect(response);
  await context.settle();

  assert.equal(seenKey, 'good-token');
});

test('missing fields are rejected before the model is called', async () => {
  let called = false;
  globalThis.fetch = async () => {
    called = true;
    return new Response('', { status: 200 });
  };

  const response = await worker.fetch(post('/v1/word', { word: 'only' }), env(), ctx());

  assert.equal(response.status, 400);
  assert.equal(called, false, 'a bad request must not cost money');
});

test('a word lookup streams plain text chunks', async () => {
  globalThis.fetch = fakeGemini(['It means ', 'give and take.']);

  const context = ctx();
  const response = await worker.fetch(
    post('/v1/word', { word: 'reciprocity', sentence: 'That pause is where reciprocity begins.' }),
    env(),
    context,
  );

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type'), /text\/event-stream/);

  const events = await collect(response);
  await context.settle();

  assert.deepEqual(events, [
    '{"text":"It means "}',
    '{"text":"give and take."}',
    '[DONE]',
  ]);
});

test('explaining a sentence streams too', async () => {
  globalThis.fetch = fakeGemini(['Wait, and people talk.']);

  const context = ctx();
  const response = await worker.fetch(
    post('/v1/explain', { sentence: 'That pause is where reciprocity begins.' }),
    env(),
    context,
  );
  const events = await collect(response);
  await context.settle();

  assert.deepEqual(events, ['{"text":"Wait, and people talk."}', '[DONE]']);
});

test('the key is sent to Gemini as a header, never in the URL', async () => {
  // A key in a query string ends up in logs and proxies.
  globalThis.fetch = fakeGemini(['x']);

  const context = ctx();
  const response = await worker.fetch(post('/v1/explain', { sentence: 'A sentence.' }), env(), context);
  await collect(response);
  await context.settle();

  const { url, options, body } = fakeGemini.lastCall;
  assert.doesNotMatch(url, /test-key/);
  assert.equal(options.headers['x-goog-api-key'], 'test-key');
  assert.equal(body.model, 'gemini-3.6-flash');
  assert.equal(body.stream, true);
});

test('an upstream failure never leaks the upstream body', async () => {
  globalThis.fetch = fakeGemini([], { ok: false, status: 403 });

  const response = await worker.fetch(post('/v1/explain', { sentence: 'A sentence.' }), env(), ctx());
  const body = await response.json();

  assert.equal(response.status, 502);
  assert.doesNotMatch(body.error, /upstream said no/);
});

test('a missing server key is a server error, not a silent empty answer', async () => {
  const response = await worker.fetch(
    post('/v1/word', { word: 'a', sentence: 'b' }),
    { ALLOWED_TOKENS: 'good-token' },
    ctx(),
  );

  assert.equal(response.status, 500);
});

test('an unknown path is a 404', async () => {
  const response = await worker.fetch(post('/v1/anything', {}), env(), ctx());
  assert.equal(response.status, 404);
});
