-- =============================================================
-- 01_audit_trigger.sql  —  Row-Level Audit Log Trigger
-- MerchantLens: Merchant Settlement & Analytics Database
-- =============================================================
-- This trigger fires AFTER INSERT / UPDATE / DELETE on every
-- financial table and writes an immutable row to audit_log.
--
-- Why a trigger instead of application-layer logging?
--   • Tamper-resistant: audit happens even if app is bypassed
--   • Consistent: no per-service boilerplate
--   • Captures DB-level operations (migrations, direct psql edits)
-- =============================================================

CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- runs as function owner, captures correct user
AS $$
DECLARE
    v_record_id TEXT;
    v_pk_col    TEXT;
    v_old_data  JSONB := NULL;
    v_new_data  JSONB := NULL;
BEGIN
    -- Look up the table's primary-key column from the catalog instead of
    -- guessing a name from the table name (disputes -> dispute_id, not
    -- disputes_id, which previously made every record_id 'UNKNOWN').
    SELECT a.attname INTO v_pk_col
    FROM   pg_index i
    JOIN   pg_attribute a ON a.attrelid = i.indrelid
                         AND a.attnum   = ANY (i.indkey)
    WHERE  i.indrelid = TG_RELID
      AND  i.indisprimary
    LIMIT  1;

    IF TG_OP = 'DELETE' THEN
        v_old_data  := to_jsonb(OLD);
        v_record_id := v_old_data ->> v_pk_col;
    ELSIF TG_OP = 'INSERT' THEN
        v_new_data  := to_jsonb(NEW);
        v_record_id := v_new_data ->> v_pk_col;
    ELSE  -- UPDATE
        v_old_data  := to_jsonb(OLD);
        v_new_data  := to_jsonb(NEW);
        v_record_id := v_new_data ->> v_pk_col;
    END IF;

    INSERT INTO audit_log (
        table_name,
        operation,
        record_id,
        changed_by,
        changed_at,
        old_data,
        new_data
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP::audit_operation,
        COALESCE(v_record_id, 'UNKNOWN'),
        session_user,
        NOW(),
        v_old_data,
        v_new_data
    );

    -- Must return NEW for INSERT/UPDATE, OLD for DELETE
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_audit_log() IS
    'Generic audit trigger function. Logs every DML operation on attached tables.';

-- -----------------------------------------------------------
-- Attach to all financial tables
-- -----------------------------------------------------------
-- captures
CREATE TRIGGER trg_audit_captures
    AFTER INSERT OR UPDATE OR DELETE ON captures
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- refunds
CREATE TRIGGER trg_audit_refunds
    AFTER INSERT OR UPDATE OR DELETE ON refunds
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- settlement_batches
CREATE TRIGGER trg_audit_settlement_batches
    AFTER INSERT OR UPDATE OR DELETE ON settlement_batches
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- payouts
CREATE TRIGGER trg_audit_payouts
    AFTER INSERT OR UPDATE OR DELETE ON payouts
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- disputes
CREATE TRIGGER trg_audit_disputes
    AFTER INSERT OR UPDATE OR DELETE ON disputes
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- authorizations
CREATE TRIGGER trg_audit_authorizations
    AFTER INSERT OR UPDATE OR DELETE ON authorizations
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- -----------------------------------------------------------
-- Helper view: recent audit events (last 24 hours)
-- -----------------------------------------------------------
CREATE OR REPLACE VIEW v_recent_audit AS
SELECT
    audit_id,
    table_name,
    operation,
    record_id,
    changed_by,
    changed_at,
    -- Show only changed fields for UPDATEs to reduce noise
    CASE
        WHEN operation = 'UPDATE' THEN
            (SELECT jsonb_object_agg(key, new_data->key)
             FROM jsonb_each(new_data)
             WHERE new_data->key IS DISTINCT FROM old_data->key)
        ELSE new_data
    END AS changed_fields
FROM audit_log
WHERE changed_at > NOW() - INTERVAL '24 hours'
ORDER BY changed_at DESC;

COMMENT ON VIEW v_recent_audit IS
    'Recent audit events. For UPDATEs, shows only the fields that actually changed.';
