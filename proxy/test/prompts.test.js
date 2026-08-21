import assert from 'node:assert/strict';
import { test } from 'node:test';

import { sentencePrompt, wordPrompt } from '../src/prompts.js';

test('the word prompt carries both the word and its sentence', () => {
  const { system, input } = wordPrompt({
    word: 'reciprocity',
    sentence: 'That pause is where reciprocity begins.',
  });

  assert.match(input, /reciprocity/);
  assert.match(input, /That pause is where/);
  assert.match(system, /in the sentence/i);
});

test('the word prompt asks for the meaning here, not every meaning', () => {
  // The whole point of the feature: a dictionary already gives the general sense.
  const { system } = wordPrompt({ word: 'x', sentence: 'y' });
  assert.match(system, /HERE/);
  assert.match(system, /not every meaning/i);
});

test('the sentence prompt forbids summarising', () => {
  // "Simpler" must not become "shorter" — the reader wants the author's meaning.
  const { system } = sentencePrompt({ sentence: 'A hard sentence.' });
  assert.match(system, /Do not summarise/i);
  assert.match(system, /do not add information/i);
});

test('both prompts forbid a preamble', () => {
  for (const { system } of [wordPrompt({ word: 'a', sentence: 'b' }), sentencePrompt({ sentence: 'c' })]) {
    assert.match(system, /do not add a preamble/i);
  }
});
