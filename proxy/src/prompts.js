/**
 * The prompts live here, on the server, not in the app.
 *
 * Two reasons. Wording is the main lever on answer quality, and this way it can
 * be changed with a redeploy instead of an App Store review. And it keeps the
 * app ignorant of which model it is talking to, so switching providers again
 * costs one file, not a release.
 */

/** Hard caps. A reader cannot press a word longer than this, so anything bigger is abuse. */
export const LIMITS = {
  word: 80,
  sentence: 1200,
};

const WORD_SYSTEM = [
  'You help someone reading a book in English that is a little above their level.',
  'They long-pressed one word and want to know what it means in the sentence they are looking at.',
  '',
  'Answer in at most two short sentences, in plain everyday English.',
  'Explain the meaning it carries HERE, in this sentence — not every meaning it can have.',
  'If it is being used figuratively or as part of an idiom, say so plainly.',
  'Do not restate the question, do not greet, do not add a preamble, do not use bullet points.',
  'Do not put the word in quotes. Just answer.',
].join('\n');

const SENTENCE_SYSTEM = [
  'You help someone reading a book in English that is a little above their level.',
  'They selected one sentence they found hard and want it in plainer words.',
  '',
  'Give the same meaning in simpler English, in at most three short sentences.',
  'Keep everything the author said. Do not summarise it away, do not add information,',
  'do not add your own opinion, and do not comment on the writing.',
  'Do not restate the original, do not greet, do not add a preamble. Just the plainer version.',
].join('\n');

export function wordPrompt({ word, sentence }) {
  return {
    system: WORD_SYSTEM,
    input: `Sentence: ${sentence}\n\nWord: ${word}\n\nWhat does "${word}" mean in this sentence?`,
  };
}

export function sentencePrompt({ sentence }) {
  return {
    system: SENTENCE_SYSTEM,
    input: `Sentence: ${sentence}\n\nPut this in plainer English.`,
  };
}
