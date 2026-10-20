// Thin client for the MerchantLens Spring Boot API (/api/v1/disputes).
// fetch is injectable so the client can be tested without a network.

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

const MESSAGES = {
  401: 'Not authenticated. Check the JWT.',
  403: 'Your role is not allowed to do that.',
  404: 'Not found.',
  501: 'Not implemented by the API yet.',
};

export function createClient({ baseUrl = '', token = '', fetchImpl = globalThis.fetch } = {}) {
  const root = baseUrl.replace(/\/+$/, '');

  async function request(path, { method = 'GET', params } = {}) {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params ?? {})) {
      if (value !== undefined && value !== null && String(value).trim() !== '') {
        query.set(key, String(value).trim());
      }
    }
    const qs = query.toString();
    const url = `${root}${path}${qs ? `?${qs}` : ''}`;

    const headers = { Accept: 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;

    let response;
    try {
      response = await fetchImpl(url, { method, headers });
    } catch (err) {
      throw new ApiError(0, `Could not reach the API: ${err.message}`);
    }
    if (!response.ok) {
      throw new ApiError(response.status, MESSAGES[response.status] ?? `Request failed (${response.status}).`);
    }
    return response.json();
  }

  return {
    getDisputes: (filters = {}) =>
      request('/api/v1/disputes', {
        params: {
          updated_since: filters.updatedSince,
          merchant_id: filters.merchantId,
          status: filters.status,
        },
      }),
    getSummary: () => request('/api/v1/disputes/summary'),
    escalate: (id) =>
      request(`/api/v1/disputes/${encodeURIComponent(id)}/escalate`, { method: 'POST' }),
  };
}
