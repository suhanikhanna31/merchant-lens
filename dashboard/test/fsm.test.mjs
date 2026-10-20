import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ALLOWED_TRANSITIONS, ALL_STATES, explainTransition, isTerminal, isValidTransition, nextStates } from '../src/fsm.js';

test('valid and invalid transitions', () => {
  assert.equal(isValidTransition('RECEIVED', 'UNDER_REVIEW'), true);
  assert.equal(isValidTransition('UNDER_REVIEW', 'WON'), false); // the case CI tests in SQL
  assert.equal(isValidTransition('WON', 'LOST'), false);
  assert.equal(isValidTransition('WON', 'WON'), true); // no-op, like the trigger
});

test('terminal states have no next states', () => {
  for (const s of ['WON', 'LOST', 'WITHDRAWN']) {
    assert.equal(isTerminal(s), true);
    assert.deepEqual(nextStates(s), []);
  }
  assert.deepEqual(nextStates('NOPE'), []);
});

test('explainTransition', () => {
  assert.equal(explainTransition('RECEIVED', 'UNDER_REVIEW'), null);
  assert.match(explainTransition('WON', 'LOST'), /terminal state WON/);
  assert.match(explainTransition('UNDER_REVIEW', 'WON'), /Allowed from UNDER_REVIEW: EVIDENCE_SUBMITTED, WITHDRAWN/);
});

test('every transition target is a known state', () => {
  for (const targets of Object.values(ALLOWED_TRANSITIONS)) {
    for (const t of targets) assert.ok(ALL_STATES.includes(t), t);
  }
});

// Drift guard: parse the JSONB literal from the real trigger and compare.
test('matches triggers/02_dispute_fsm.sql', () => {
  const sqlPath = fileURLToPath(new URL('../../triggers/02_dispute_fsm.sql', import.meta.url));
  const sql = readFileSync(sqlPath, 'utf8');
  const match = sql.match(/allowed_transitions JSONB := '(\{[\s\S]*?\})'/);
  assert.ok(match, 'allowed_transitions literal not found in trigger');
  assert.deepEqual(JSON.parse(match[1]), ALLOWED_TRANSITIONS);
});
