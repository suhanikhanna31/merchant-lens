-- devsecops/db_tests.sql
-- pgTAP unit tests — run in the CI "DB Validation" stage, AFTER schema,
-- triggers, procedures and seed data have been applied.
--
-- Run with:
--   psql -v ON_ERROR_STOP=1 -d merchantlens_test -f devsecops/db_tests.sql
--   OR pg_prove -d merchantlens_test devsecops/db_tests.sql

CREATE EXTENSION IF NOT EXISTS pgtap;

BEGIN;

SELECT plan(24);

-- ─── Schema existence ────────────────────────────────────────────────────────
SELECT has_table('public', 'merchants',          'merchants table exists');
SELECT has_table('public', 'authorizations',     'authorizations table exists');
SELECT has_table('public', 'captures',           'captures table exists');
SELECT has_table('public', 'refunds',            'refunds table exists');
SELECT has_table('public', 'disputes',           'disputes table exists');
SELECT has_table('public', 'settlement_batches', 'settlement_batches table exists');
SELECT has_table('public', 'payouts',            'payouts table exists');
SELECT has_table('public', 'audit_log',          'audit_log table exists');

-- ─── Critical columns ────────────────────────────────────────────────────────
SELECT has_column('public', 'captures',  'capture_amount_paise', 'captures.capture_amount_paise exists');
SELECT has_column('public', 'disputes',  'status',               'disputes.status exists');
SELECT has_column('public', 'audit_log', 'changed_at',           'audit_log.changed_at exists');

-- ─── Triggers ────────────────────────────────────────────────────────────────
SELECT has_trigger('public', 'disputes', 'trg_dispute_fsm',    'Dispute FSM trigger exists');
SELECT has_trigger('public', 'disputes', 'trg_audit_disputes', 'Audit trigger exists on disputes');
SELECT has_trigger('public', 'captures', 'trg_audit_captures', 'Audit trigger exists on captures');

-- ─── Functions / procedures ──────────────────────────────────────────────────
SELECT has_function('public', 'run_settlement',            'run_settlement exists');
SELECT has_function('public', 'compute_capture_fee',       'compute_capture_fee exists');
SELECT has_function('public', 'escalate_overdue_disputes', 'escalate_overdue_disputes exists');

-- ─── Dispute FSM behaviour ───────────────────────────────────────────────────
-- Fresh dispute built from an existing seeded capture so FKs are satisfied.
INSERT INTO disputes (capture_id, merchant_id, cb_reference, reason,
                      disputed_amount_paise, status, response_due_by)
SELECT capture_id, merchant_id, 'CI-TEST-FSM-001', reason,
       disputed_amount_paise, 'RECEIVED', CURRENT_DATE + 7
FROM   disputes
LIMIT  1;

SELECT throws_ok(
    $$UPDATE disputes SET status = 'WON' WHERE cb_reference = 'CI-TEST-FSM-001'$$,
    'P0001', NULL,
    'RECEIVED -> WON is rejected by the FSM'
);

SELECT lives_ok(
    $$UPDATE disputes SET status = 'UNDER_REVIEW' WHERE cb_reference = 'CI-TEST-FSM-001'$$,
    'RECEIVED -> UNDER_REVIEW is allowed'
);

SELECT cmp_ok(
    (SELECT count(*) FROM audit_log
     WHERE table_name = 'disputes'
       AND record_id = (SELECT dispute_id::text FROM disputes WHERE cb_reference = 'CI-TEST-FSM-001')
       AND operation = 'UPDATE'),
    '>=', 1::bigint,
    'Status change on disputes is written to audit_log'
);

SELECT lives_ok(
    $$UPDATE disputes SET status = 'WITHDRAWN' WHERE cb_reference = 'CI-TEST-FSM-001'$$,
    'UNDER_REVIEW -> WITHDRAWN is allowed'
);

SELECT throws_ok(
    $$UPDATE disputes SET status = 'UNDER_REVIEW' WHERE cb_reference = 'CI-TEST-FSM-001'$$,
    'P0001', NULL,
    'Terminal state WITHDRAWN cannot be left'
);

-- ─── Constraints ─────────────────────────────────────────────────────────────
SELECT throws_ok(
    $$INSERT INTO disputes (capture_id, merchant_id, cb_reference, reason,
                            disputed_amount_paise, response_due_by)
      SELECT capture_id, merchant_id, 'CI-TEST-ZERO', reason, 0, CURRENT_DATE
      FROM disputes LIMIT 1$$,
    '23514', NULL,
    'Dispute amount must be positive (CHECK constraint)'
);

-- ─── Settlement procedure ────────────────────────────────────────────────────
SELECT lives_ok(
    $$SELECT run_settlement((SELECT merchant_id FROM merchants ORDER BY merchant_id LIMIT 1), CURRENT_DATE)$$,
    'run_settlement executes without error'
);

SELECT * FROM finish();
ROLLBACK;
