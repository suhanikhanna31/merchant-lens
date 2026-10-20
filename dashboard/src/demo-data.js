// Synthetic data so the dashboard is usable while the API's service layer is
// still a stub. Merchant names and numbers are made up.

export const DEMO_DISPUTES = [
  { id: 'D-1001', merchantId: 'M-01', status: 'RECEIVED', updatedAt: '2026-10-20T08:15:00Z' },
  { id: 'D-1002', merchantId: 'M-02', status: 'UNDER_REVIEW', updatedAt: '2026-10-20T09:40:00Z' },
  { id: 'D-1003', merchantId: 'M-02', status: 'EVIDENCE_SUBMITTED', updatedAt: '2026-10-19T17:05:00Z' },
  { id: 'D-1004', merchantId: 'M-03', status: 'ARBITRATION', updatedAt: '2026-10-18T11:30:00Z' },
  { id: 'D-1005', merchantId: 'M-01', status: 'WON', updatedAt: '2026-10-17T13:00:00Z' },
  { id: 'D-1006', merchantId: 'M-04', status: 'LOST', updatedAt: '2026-10-16T10:20:00Z' },
  { id: 'D-1007', merchantId: 'M-03', status: 'WITHDRAWN', updatedAt: '2026-10-15T15:45:00Z' },
];

export const DEMO_SUMMARY = [
  { merchantName: 'Merchant A', cbRatioPct: 0.64, alert: false },
  { merchantName: 'Merchant B', cbRatioPct: 1.38, alert: true },
  { merchantName: 'Merchant C', cbRatioPct: 0.42, alert: false },
];
