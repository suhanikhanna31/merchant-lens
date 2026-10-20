import test from 'node:test';
import assert from 'node:assert/strict';
import { renderDisputes, renderStats, renderSummary } from '../src/render.js';

// Minimal DOM stand-in (no jsdom: the project keeps zero dependencies).
class FakeNode {
  constructor(tag) { this.tag = tag; this.children = []; this.attrs = {}; this.listeners = {}; this.textContent = ''; this.className = ''; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children = nodes; }
  setAttribute(k, v) { this.attrs[k] = v; }
  addEventListener(type, fn) { this.listeners[type] = fn; }
  all() { return [this, ...this.children.flatMap((c) => c.all())]; }
  text() { return this.all().map((n) => n.textContent).join(' '); }
  find(tag) { return this.all().filter((n) => n.tag === tag); }
}
const doc = { createElement: (tag) => new FakeNode(tag) };

test('renderStats shows total/open/closed', () => {
  const box = new FakeNode('div');
  renderStats(doc, box, [{ status: 'RECEIVED' }, { status: 'WON' }]);
  assert.match(box.text(), /2 Total/);
  assert.match(box.text(), /1 Open/);
  assert.match(box.text(), /1 Closed/);
});

test('renderSummary flags alerts and handles empty', () => {
  const box = new FakeNode('div');
  renderSummary(doc, box, [{ merchantName: 'B', cbRatioPct: 1.38, alert: true }]);
  assert.match(box.text(), /1\.38%/);
  assert.match(box.text(), /ALERT/);
  renderSummary(doc, box, []);
  assert.match(box.text(), /No chargeback data/);
});

test('renderDisputes treats API data as text, not markup', () => {
  const box = new FakeNode('div');
  renderDisputes(doc, box, [{ id: '<img src=x onerror=alert(1)>', merchantId: 'M', status: 'RECEIVED', updatedAt: '2026-10-20T08:15:00Z' }]);
  const cell = box.find('td')[0];
  assert.equal(cell.textContent, '<img src=x onerror=alert(1)>');
  assert.equal(cell.children.length, 0);
});

test('Escalate button only appears where the FSM allows ARBITRATION', () => {
  const box = new FakeNode('div');
  const seen = [];
  const disputes = ['RECEIVED', 'UNDER_REVIEW', 'EVIDENCE_SUBMITTED', 'ARBITRATION', 'WON'].map((status, i) => ({ id: `D${i}`, merchantId: 'M', status, updatedAt: '2026-10-20T08:15:00Z' }));
  renderDisputes(doc, box, disputes, { onEscalate: (d) => seen.push(d.id) });
  const buttons = box.find('button');
  assert.equal(buttons.length, 1);
  buttons[0].listeners.click();
  assert.deepEqual(seen, ['D2']);
});

test('no buttons without an onEscalate handler; empty state', () => {
  const box = new FakeNode('div');
  renderDisputes(doc, box, [{ id: 'D', merchantId: 'M', status: 'EVIDENCE_SUBMITTED', updatedAt: '2026-10-20T08:15:00Z' }]);
  assert.equal(box.find('button').length, 0);
  renderDisputes(doc, box, []);
  assert.match(box.text(), /No disputes match/);
});
