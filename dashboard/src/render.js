// DOM rendering. Everything goes through textContent / createElement, never
// innerHTML, so API data cannot inject markup (the API is untrusted input here).

import { isValidTransition, isTerminal } from './fsm.js';
import { formatRatio, formatTimestamp, sortSummary, summarizeDisputes } from './format.js';

function el(doc, tag, { className, text, attrs } = {}) {
  const node = doc.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  for (const [k, v] of Object.entries(attrs ?? {})) node.setAttribute(k, v);
  return node;
}

export function renderStats(doc, container, disputes) {
  const { total, open, closed } = summarizeDisputes(disputes);
  container.replaceChildren(
    ...[
      ['Total', total],
      ['Open', open],
      ['Closed', closed],
    ].map(([label, value]) => {
      const card = el(doc, 'div', { className: 'stat' });
      card.append(el(doc, 'span', { className: 'stat-value', text: String(value) }));
      card.append(el(doc, 'span', { className: 'stat-label', text: label }));
      return card;
    }),
  );
}

export function renderSummary(doc, container, rows) {
  const sorted = sortSummary(rows);
  if (sorted.length === 0) {
    container.replaceChildren(el(doc, 'p', { className: 'empty', text: 'No chargeback data.' }));
    return;
  }
  const list = el(doc, 'ul', { className: 'summary-list' });
  for (const row of sorted) {
    const item = el(doc, 'li', { className: row.alert ? 'summary-row alert' : 'summary-row' });
    item.append(el(doc, 'span', { className: 'merchant', text: String(row.merchantName) }));
    item.append(el(doc, 'span', { className: 'ratio', text: formatRatio(row.cbRatioPct) }));
    if (row.alert) item.append(el(doc, 'span', { className: 'badge badge-alert', text: 'ALERT' }));
    list.append(item);
  }
  container.replaceChildren(list);
}

export function renderDisputes(doc, container, disputes, { onEscalate } = {}) {
  if (disputes.length === 0) {
    container.replaceChildren(el(doc, 'p', { className: 'empty', text: 'No disputes match.' }));
    return;
  }
  const table = el(doc, 'table');
  const head = el(doc, 'tr');
  for (const label of ['Dispute', 'Merchant', 'Status', 'Updated', '']) {
    head.append(el(doc, 'th', { text: label, attrs: { scope: 'col' } }));
  }
  const thead = el(doc, 'thead');
  thead.append(head);
  table.append(thead);

  const body = el(doc, 'tbody');
  for (const d of disputes) {
    const row = el(doc, 'tr');
    row.append(el(doc, 'td', { text: String(d.id) }));
    row.append(el(doc, 'td', { text: String(d.merchantId) }));
    const statusCell = el(doc, 'td');
    const cls = isTerminal(d.status) ? 'badge badge-closed' : 'badge badge-open';
    statusCell.append(el(doc, 'span', { className: cls, text: String(d.status) }));
    row.append(statusCell);
    row.append(el(doc, 'td', { text: formatTimestamp(d.updatedAt) }));

    const actions = el(doc, 'td');
    // Same rule as the database trigger: only EVIDENCE_SUBMITTED may enter ARBITRATION.
    if (onEscalate && d.status !== 'ARBITRATION' && isValidTransition(d.status, 'ARBITRATION')) {
      const btn = el(doc, 'button', { text: 'Escalate', attrs: { type: 'button' } });
      btn.addEventListener('click', () => onEscalate(d));
      actions.append(btn);
    }
    row.append(actions);
    body.append(row);
  }
  table.append(body);
  container.replaceChildren(table);
}
