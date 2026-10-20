-- =============================================================
-- 02_dispute_fsm.sql  —  Chargeback State-Machine Trigger
-- MerchantLens: Merchant Settlement & Analytics Database
-- =============================================================
-- Valid state transitions:
--
--   RECEIVED ──────────────► UNDER_REVIEW
--   RECEIVED ──────────────► WITHDRAWN
--   UNDER_REVIEW ──────────► EVIDENCE_SUBMITTED
--   UNDER_REVIEW ──────────► WITHDRAWN
--   EVIDENCE_SUBMITTED ────► WON
--   EVIDENCE_SUBMITTED ────► LOST
--   EVIDENCE_SUBMITTED ────► ARBITRATION
--   ARBITRATION ───────────► WON
--   ARBITRATION ───────────► LOST
--
-- Any other transition is rejected with SQLSTATE P0001.
-- This enforces the FSM at the DATABASE layer, making it
-- impossible for buggy application code to corrupt lifecycle.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_dispute_fsm()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    allowed_transitions JSONB := '{
        "RECEIVED":            ["UNDER_REVIEW", "WITHDRAWN"],
        "UNDER_REVIEW":        ["EVIDENCE_SUBMITTED", "WITHDRAWN"],
        "EVIDENCE_SUBMITTED":  ["WON", "LOST", "ARBITRATION"],
        "ARBITRATION":         ["WON", "LOST"]
    }';
    old_status TEXT := OLD.status::TEXT;
    new_status TEXT := NEW.status::TEXT;
    valid_nexts JSONB;
BEGIN
    -- No status change: nothing to validate
    IF old_status = new_status THEN
        RETURN NEW;
    END IF;

    -- Terminal states cannot be transitioned out of
    IF old_status IN ('WON', 'LOST', 'WITHDRAWN') THEN
        RAISE EXCEPTION
            'Dispute % is in terminal state %. No further transitions allowed.',
            OLD.dispute_id, old_status
            USING ERRCODE = 'P0001';
    END IF;

    -- Look up allowed next states
    valid_nexts := allowed_transitions -> old_status;

    IF valid_nexts IS NULL OR NOT (valid_nexts @> to_jsonb(new_status)) THEN
        RAISE EXCEPTION
            'Invalid dispute transition: % → % for dispute_id=%. '
            'Allowed transitions from %: %',
            old_status, new_status, OLD.dispute_id,
            old_status, valid_nexts::TEXT
            USING ERRCODE = 'P0001';
    END IF;

    -- Side-effects on terminal state entry
    IF new_status IN ('WON', 'LOST', 'WITHDRAWN') THEN
        NEW.resolved_at := NOW();
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_dispute_fsm() IS
    'Enforces the chargeback state machine. Rejects invalid transitions with SQLSTATE P0001.';

CREATE TRIGGER trg_dispute_fsm
    BEFORE UPDATE OF status ON disputes
    FOR EACH ROW EXECUTE FUNCTION fn_dispute_fsm();

COMMENT ON TRIGGER trg_dispute_fsm ON disputes IS
    'State-machine guard for dispute lifecycle. Fires before any status update.';

-- -----------------------------------------------------------
-- Helper: show FSM transition diagram as a query result
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW v_dispute_fsm_transitions AS
SELECT
    src.status AS from_status,
    src.dst AS to_status
FROM (
    VALUES
        ('RECEIVED'::dispute_status,           'UNDER_REVIEW'::dispute_status),
        ('RECEIVED',                            'WITHDRAWN'),
        ('UNDER_REVIEW',                        'EVIDENCE_SUBMITTED'),
        ('UNDER_REVIEW',                        'WITHDRAWN'),
        ('EVIDENCE_SUBMITTED',                  'WON'),
        ('EVIDENCE_SUBMITTED',                  'LOST'),
        ('EVIDENCE_SUBMITTED',                  'ARBITRATION'),
        ('ARBITRATION',                         'WON'),
        ('ARBITRATION',                         'LOST')
) AS src(status, dst)
ORDER BY src.status, src.dst;

COMMENT ON VIEW v_dispute_fsm_transitions IS
    'Self-documenting view of valid dispute state transitions.';
