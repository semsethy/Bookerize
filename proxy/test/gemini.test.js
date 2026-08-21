import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createSseParser, errorFromRecord, textFromRecord } from '../src/gemini.js';

test('parses one complete SSE record', () => {
  const parse = createSseParser();
  const records = parse('event: step.delta\ndata: {"delta":{"type":"text","text":"hi"}}\n\n');

  assert.equal(records.length, 1);
  assert.equal(records[0].event, 'step.delta');
});

test('waits for a record split across chunk boundaries', () => {
  // The network splits wherever it likes; half a JSON payload must not be parsed.
  const parse = createSseParser();

  assert.deepEqual(parse('event: step.delta\ndata: {"delta":{"type":'), []);
  assert.deepEqual(parse('"text","text":"split"}}'), []);

  const records = parse('\n\n');
  assert.equal(records.length, 1);
  assert.equal(textFromRecord(records[0]), 'split');
});

test('handles several records arriving in one chunk', () => {
  const parse = createSseParser();
  const records = parse(
    'event: step.delta\ndata: {"delta":{"type":"text","text":"a"}}\n\n' +
      'event: step.delta\ndata: {"delta":{"type":"text","text":"b"}}\n\n',
  );

  assert.deepEqual(records.map(textFromRecord), ['a', 'b']);
});

test('extracts text only from content events', () => {
  const ignored = [
    { event: 'interaction.created', data: '{"interaction":{"id":"v1_x"}}' },
    { event: 'step.start', data: '{"index":1,"step":{"type":"model_output"}}' },
    { event: 'step.stop', data: '{"index":1}' },
    { event: 'interaction.completed', data: '{"interaction":{"status":"completed"}}' },
    { event: 'done', data: '[DONE]' },
  ];

  for (const record of ignored) {
    assert.equal(textFromRecord(record), null, `${record.event} should carry no text`);
  }
});

test('ignores a non-text delta', () => {
  // Interactions can stream things that are not prose; we only forward text.
  const record = { event: 'step.delta', data: '{"delta":{"type":"thought","text":"..."}}' };
  assert.equal(textFromRecord(record), null);
});

test('malformed JSON is skipped rather than thrown', () => {
  assert.equal(textFromRecord({ event: 'step.delta', data: '{not json' }), null);
});

test('an empty text delta is not forwarded', () => {
  const record = { event: 'step.delta', data: '{"delta":{"type":"text","text":""}}' };
  assert.equal(textFromRecord(record), null);
});

test('a realistic stream reassembles into the full answer', () => {
  const parse = createSseParser();
  const stream = [
    'event: interaction.created\ndata: {"interaction":{"id":"v1_a"},"event_type":"interaction.created"}\n\n',
    'event: step.start\ndata: {"index":1,"step":{"type":"model_output"},"event_type":"step.start"}\n\n',
    'event: step.delta\ndata: {"index":1,"delta":{"text":"It means ","type":"text"},"event_type":"step.delta"}\n\n',
    'event: step.delta\ndata: {"index":1,"delta":{"text":"give and take.","type":"text"},"event_type":"step.delta"}\n\n',
    'event: step.stop\ndata: {"index":1,"event_type":"step.stop"}\n\n',
    'event: done\ndata: [DONE]\n\n',
  ];

  let answer = '';
  for (const chunk of stream) {
    for (const record of parse(chunk)) {
      const text = textFromRecord(record);
      if (text !== null) answer += text;
    }
  }

  assert.equal(answer, 'It means give and take.');
});

test('an upstream error event is turned into something a reader can act on', () => {
  // Gemini reports failures inside a 200 response. Ignoring unknown events made
  // a quota error arrive as a blank card saying nothing.
  const quota = errorFromRecord({
    event: 'error',
    data: JSON.stringify({
      error: { message: 'You exceeded your current quota. Quota exceeded for metric: generate_content_free_tier_requests, limit: 20' },
    }),
  });

  assert.match(quota, /free Gemini quota is used up/);
  assert.match(quota, /resets tomorrow/);
  assert.doesNotMatch(quota, /generativelanguage|metric:/, 'no raw Google internals');
});

test('a refused key is named as such', () => {
  const message = errorFromRecord({
    event: 'error',
    data: JSON.stringify({ error: { message: 'API key not valid. PERMISSION_DENIED' } }),
  });
  assert.match(message, /GEMINI_API_KEY/);
});

test('an unparseable error still says something', () => {
  assert.match(errorFromRecord({ event: 'error', data: 'not json' }), /without explaining/);
});

test('ordinary events are not treated as errors', () => {
  for (const event of ['step.delta', 'step.start', 'interaction.completed', 'done']) {
    assert.equal(errorFromRecord({ event, data: '{}' }), null);
  }
});
