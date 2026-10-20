import test from 'node:test';
import assert from 'node:assert/strict';
import { countByStatus, filterDisputes, formatRatio, formatTimestamp, sortSummary, summarizeDisputes } from '../src/format.js';
import { DEMO_DISPUTES } from '../src/demo-data.js';

test('formatRatio', () => {
  assert.equal(formatRatio(1.384), '1.38%');
  assert.equal(formatRatio('0.4'), '0.40%');
  assert.equal(formatRatio(undefined), 'n/a');
  assert.equal(formatRatio('abc'), 'n/a');
});

test('formatTimestamp', () => {
  assert.equal(formatTimestamp('2026-10-20T08:15:00Z'), '2026-10-20 08:15:00 UTC');
  assert.equal(formatTimestamp('garbage'), 'unknown');
});

test('countByStatus lists every state and ignores unknown ones', () => {
  const counts = countByStatus([...DEMO_DISPUTES, { status: 'BOGUS' }, null]);
  assert.equal(counts.RECEIVED, 1);
  assert.equal(counts.WITHDRAWN, 1);
  assert.equal(Object.values(counts).reduce((a, b) => a + b, 0), DEMO_DISPUTES.length);
});

test('summarizeDisputes', () => {
  assert.deepEqual(summarizeDisputes(DEMO_DISPUTES), { total: 7, open: 4, closed: 3 });
  assert.deepEqual(summarizeDisputes(null), { total: 0, open: 0, closed: 0 });
});

test('sortSummary puts alerts first, then highest ratio, without mutating input', () => {
  const rows = [
    { merchantName: 'A', cbRatioPct: 0.9, alert: false },
    { merchantName: 'B', cbRatioPct: 1.4, alert: true },
    { merchantName: 'C', cbRatioPct: 0.1, alert: false },
    { merchantName: 'D', cbRatioPct: 1.1, alert: true },
  ];
  assert.deepEqual(sortSummary(rows).map((r) => r.merchantName), ['B', 'D', 'A', 'C']);
  assert.equal(rows[0].merchantName, 'A');
  assert.deepEqual(sortSummary(undefined), []);
});

test('filterDisputes', () => {
  assert.equal(filterDisputes(DEMO_DISPUTES, { status: 'WON' }).length, 1);
  assert.equal(filterDisputes(DEMO_DISPUTES, { merchantId: ' m-02 ' }).length, 2);
  assert.equal(filterDisputes(DEMO_DISPUTES, {}).length, DEMO_DISPUTES.length);
  assert.equal(filterDisputes(DEMO_DISPUTES).length, DEMO_DISPUTES.length);
});
