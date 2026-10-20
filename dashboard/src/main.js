import { createClient } from './api.js';
import { DEMO_DISPUTES, DEMO_SUMMARY } from './demo-data.js';
import { ALL_STATES } from './fsm.js';
import { filterDisputes } from './format.js';
import { renderDisputes, renderStats, renderSummary } from './render.js';

const $ = (id) => document.getElementById(id);

const state = { disputes: [], demo: true };

function setMessage(text, isError = false) {
  const box = $('message');
  box.textContent = text;
  box.className = isError ? 'message error' : 'message';
}

function redraw() {
  const visible = filterDisputes(state.disputes, {
    status: $('status-filter').value,
    merchantId: $('merchant-filter').value,
  });
  renderStats(document, $('stats'), state.disputes);
  renderDisputes(document, $('disputes'), visible, { onEscalate: escalate });
}

function client() {
  // The token is read from the input on each call and never stored.
  return createClient({ baseUrl: '', token: $('token').value.trim() });
}

async function load() {
  state.demo = !$('token').value.trim();
  if (state.demo) {
    state.disputes = DEMO_DISPUTES.map((d) => ({ ...d }));
    renderSummary(document, $('summary'), DEMO_SUMMARY);
    setMessage('Demo mode: showing synthetic data. Paste a JWT to query the API.');
    redraw();
    return;
  }
  try {
    const api = client();
    const [disputes, summary] = await Promise.all([api.getDisputes(), api.getSummary()]);
    state.disputes = disputes;
    renderSummary(document, $('summary'), summary);
    setMessage(`Loaded ${disputes.length} disputes from the API.`);
  } catch (err) {
    setMessage(err.message, true);
    return;
  }
  redraw();
}

async function escalate(dispute) {
  if (state.demo) {
    dispute.status = 'ARBITRATION';
    dispute.updatedAt = new Date().toISOString();
    setMessage(`Demo: ${dispute.id} moved to ARBITRATION.`);
    redraw();
    return;
  }
  try {
    const updated = await client().escalate(dispute.id);
    Object.assign(dispute, updated);
    setMessage(`${dispute.id} escalated to ARBITRATION.`);
    redraw();
  } catch (err) {
    setMessage(err.message, true);
  }
}

function init() {
  for (const s of ALL_STATES) {
    const opt = document.createElement('option');
    opt.value = s;
    opt.textContent = s;
    $('status-filter').append(opt);
  }
  $('status-filter').addEventListener('change', redraw);
  $('merchant-filter').addEventListener('input', redraw);
  $('reload').addEventListener('click', load);
  load();
}

init();
