import assert from 'node:assert/strict';
import { test } from 'node:test';

import { clean, isAllowed } from '../src/index.js';
import { LIMITS } from '../src/prompts.js';

test('accepts a token on the allow-list', () => {
  assert.equal(isAllowed('abc123', 'abc123,def456'), true);
  assert.equal(isAllowed('def456', 'abc123, def456'), true);
});

test('rejects anything not on it', () => {
  assert.equal(isAllowed('nope', 'abc123,def456'), false);
  assert.equal(isAllowed('abc12', 'abc123'), false, 'a prefix is not a match');
  assert.equal(isAllowed('abc1234', 'abc123'), false, 'a superset is not a match');
});

test('rejects empty input rather than matching an empty entry', () => {
  // A trailing comma in the secret must not create a token that is the empty string.
  assert.equal(isAllowed('', 'abc123,'), false);
  assert.equal(isAllowed(null, 'abc123'), false);
  assert.equal(isAllowed('abc123', ''), false);
  assert.equal(isAllowed('abc123', undefined), false);
});

test('revoking is removing from the list', () => {
  assert.equal(isAllowed('friend', 'me,friend'), true);
  assert.equal(isAllowed('friend', 'me'), false);
});

test('clean collapses whitespace and trims', () => {
  assert.equal(clean('  the   pause \n begins ', 100), 'the pause begins');
});

test('clean truncates to the cap so one request cannot be huge', () => {
  const long = 'a'.repeat(5000);
  assert.equal(clean(long, LIMITS.sentence).length, LIMITS.sentence);
});

test('clean rejects non-strings and blanks', () => {
  assert.equal(clean('', 100), null);
  assert.equal(clean('   ', 100), null);
  assert.equal(clean(42, 100), null);
  assert.equal(clean(null, 100), null);
  assert.equal(clean({ text: 'hi' }, 100), null);
});
