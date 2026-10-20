// Mirrors the chargeback state machine enforced by triggers/02_dispute_fsm.sql.
// The database stays the source of truth; test/fsm.test.mjs parses the SQL file
// and fails if this table ever drifts from it.

export const ALLOWED_TRANSITIONS = Object.freeze({
  RECEIVED: Object.freeze(['UNDER_REVIEW', 'WITHDRAWN']),
  UNDER_REVIEW: Object.freeze(['EVIDENCE_SUBMITTED', 'WITHDRAWN']),
  EVIDENCE_SUBMITTED: Object.freeze(['WON', 'LOST', 'ARBITRATION']),
  ARBITRATION: Object.freeze(['WON', 'LOST']),
});

export const TERMINAL_STATES = Object.freeze(['WON', 'LOST', 'WITHDRAWN']);

export const ALL_STATES = Object.freeze([
  'RECEIVED',
  'UNDER_REVIEW',
  'EVIDENCE_SUBMITTED',
  'ARBITRATION',
  'WON',
  'LOST',
  'WITHDRAWN',
]);

export function isTerminal(status) {
  return TERMINAL_STATES.includes(status);
}

export function nextStates(status) {
  return ALLOWED_TRANSITIONS[status] ?? [];
}

export function isValidTransition(from, to) {
  if (from === to) return true; // the trigger treats "no change" as a no-op
  return nextStates(from).includes(to);
}

// Human-readable reason, phrased like the trigger's own error message.
export function explainTransition(from, to) {
  if (isValidTransition(from, to)) return null;
  if (isTerminal(from)) {
    return `Dispute is in terminal state ${from}. No further transitions allowed.`;
  }
  const allowed = nextStates(from);
  return `Invalid transition ${from} -> ${to}. Allowed from ${from}: ${allowed.join(', ') || 'none'}.`;
}
