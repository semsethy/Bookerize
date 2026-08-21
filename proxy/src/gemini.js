/**
 * Talks to the Gemini Interactions API and flattens its stream into plain text.
 *
 * The app never sees this shape. Gemini emits several event types per response
 * (interaction.created, step.start, step.delta, step.stop, interaction.completed,
 * done); the app only cares about the text, so the Worker forwards just that.
 */

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions';

/**
 * Splits an SSE byte stream into `{ event, data }` records.
 *
 * Chunk boundaries fall wherever the network puts them, so a single `data:`
 * line can arrive in pieces. Anything incomplete stays in the buffer.
 */
export function createSseParser() {
  let buffer = '';

  return function push(text) {
    buffer += text;
    const records = [];

    let split;
    while ((split = buffer.indexOf('\n\n')) !== -1) {
      const block = buffer.slice(0, split);
      buffer = buffer.slice(split + 2);

      let event = 'message';
      const dataLines = [];
      for (const line of block.split('\n')) {
        if (line.startsWith('event:')) event = line.slice(6).trim();
        else if (line.startsWith('data:')) dataLines.push(line.slice(5).trim());
      }
      if (dataLines.length > 0) records.push({ event, data: dataLines.join('\n') });
    }
    return records;
  };
}

/** The incremental text in one Gemini SSE record, or null if it carries none. */
export function textFromRecord({ event, data }) {
  if (data === '[DONE]') return null;
  if (event !== 'step.delta' && event !== 'message') return null;

  let payload;
  try {
    payload = JSON.parse(data);
  } catch {
    return null; // a partial or unexpected payload is not worth failing over
  }

  if (payload?.event_type && payload.event_type !== 'step.delta') return null;
  const delta = payload?.delta;
  if (!delta || delta.type !== 'text') return null;
  return typeof delta.text === 'string' && delta.text.length > 0 ? delta.text : null;
}

/** Opens a streaming interaction. Returns the raw upstream Response. */
export async function askGemini({ apiKey, model, system, input, signal }) {
  return fetch(`${ENDPOINT}?alt=sse`, {
    method: 'POST',
    headers: {
      'x-goog-api-key': apiKey,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      input,
      system_instruction: system,
      stream: true,
      generation_config: {
        // Low but not zero: explanations should be steady, not robotic.
        temperature: 0.3,
        // A hard ceiling on cost per request. Both answers are meant to be short.
        max_output_tokens: 320,
      },
    }),
    signal,
  });
}
