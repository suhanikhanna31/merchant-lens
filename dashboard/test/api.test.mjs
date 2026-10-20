import test from 'node:test';
import assert from 'node:assert/strict';
import { ApiError, createClient } from '../src/api.js';

function fakeFetch(status = 200, body = []) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    return { ok: status >= 200 && status < 300, status, json: async () => body };
  };
  return { impl, calls };
}

test('getDisputes builds the query string and sends the bearer token', async () => {
  const { impl, calls } = fakeFetch(200, [{ id: 'D-1' }]);
  const api = createClient({ baseUrl: 'http://x/', token: 'tok', fetchImpl: impl });
  const out = await api.getDisputes({ status: 'WON', merchantId: ' M-1 ', updatedSince: '' });
  assert.deepEqual(out, [{ id: 'D-1' }]);
  assert.equal(calls[0].url, 'http://x/api/v1/disputes?merchant_id=M-1&status=WON');
  assert.equal(calls[0].init.headers.Authorization, 'Bearer tok');
});

test('no Authorization header without a token', async () => {
  const { impl, calls } = fakeFetch();
  await createClient({ fetchImpl: impl }).getSummary();
  assert.equal(calls[0].url, '/api/v1/disputes/summary');
  assert.equal('Authorization' in calls[0].init.headers, false);
});

test('escalate POSTs and encodes the id', async () => {
  const { impl, calls } = fakeFetch(200, { id: 'a/b', status: 'ARBITRATION' });
  await createClient({ fetchImpl: impl }).escalate('a/b');
  assert.equal(calls[0].url, '/api/v1/disputes/a%2Fb/escalate');
  assert.equal(calls[0].init.method, 'POST');
});

for (const [status, pattern] of [[401, /Not authenticated/], [403, /role/], [501, /Not implemented/], [500, /500/]]) {
  test(`HTTP ${status} becomes an ApiError`, async () => {
    const { impl } = fakeFetch(status);
    await assert.rejects(createClient({ fetchImpl: impl }).getSummary(), (e) => e instanceof ApiError && e.status === status && pattern.test(e.message));
  });
}

test('network failure becomes an ApiError with status 0', async () => {
  const impl = async () => { throw new Error('boom'); };
  await assert.rejects(createClient({ fetchImpl: impl }).getSummary(), (e) => e instanceof ApiError && e.status === 0 && /boom/.test(e.message));
});
