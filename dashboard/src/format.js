import { ALL_STATES, isTerminal } from './fsm.js';

export function formatRatio(value) {
  const n = Number(value);
  return Number.isFinite(n) ? `${n.toFixed(2)}%` : 'n/a';
}

export function formatTimestamp(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return 'unknown';
  return d.toISOString().replace('T', ' ').replace(/\.\d+Z$/, ' UTC');
}

// Counts per status, always returning every known state so the UI is stable.
export function countByStatus(disputes) {
  const counts = Object.fromEntries(ALL_STATES.map((s) => [s, 0]));
  for (const d of disputes) {
    if (d && Object.hasOwn(counts, d.status)) counts[d.status] += 1;
  }
  return counts;
}

export function summarizeDisputes(disputes) {
  const list = Array.isArray(disputes) ? disputes : [];
  const open = list.filter((d) => d && !isTerminal(d.status)).length;
  return { total: list.length, open, closed: list.length - open };
}

// Highest chargeback ratio first; alerting merchants always sort above the rest.
export function sortSummary(rows) {
  const list = Array.isArray(rows) ? rows : [];
  return [...list].sort((a, b) => {
    if (Boolean(b.alert) !== Boolean(a.alert)) return a.alert ? -1 : 1;
    return Number(b.cbRatioPct) - Number(a.cbRatioPct);
  });
}

export function filterDisputes(disputes, { status = '', merchantId = '' } = {}) {
  const needle = merchantId.trim().toLowerCase();
  return disputes.filter(
    (d) =>
      (!status || d.status === status) &&
      (!needle || String(d.merchantId).toLowerCase().includes(needle)),
  );
}
