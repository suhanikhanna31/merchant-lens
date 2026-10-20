-- =============================================================
-- 02_merchant_analytics.sql  —  Merchant Analytics Queries
-- MerchantLens: Merchant Settlement & Analytics Database
-- =============================================================

-- -----------------------------------------------------------
-- Q1: Rolling 7-day chargeback ratio per merchant
--     Alert threshold: > 1% is a Visa/MC risk flag
-- -----------------------------------------------------------
WITH daily_txns AS (
    SELECT
        a.merchant_id,
        DATE(a.initiated_at AT TIME ZONE 'Asia/Kolkata')    AS txn_date,
        COUNT(c.capture_id)                                  AS captures_count,
        SUM(c.capture_amount_paise)                          AS gross_paise
    FROM authorizations a
    JOIN captures c ON c.auth_id = a.auth_id
    WHERE a.initiated_at >= NOW() - INTERVAL '37 days'  -- extra window for 7-day roll
      AND c.status NOT IN ('FAILED')
    GROUP BY a.merchant_id, txn_date
),
daily_disputes AS (
    SELECT
        d.merchant_id,
        DATE(d.received_at AT TIME ZONE 'Asia/Kolkata')     AS dispute_date,
        COUNT(d.dispute_id)                                  AS dispute_count,
        SUM(d.disputed_amount_paise)                         AS disputed_paise
    FROM disputes d
    WHERE d.received_at >= NOW() - INTERVAL '37 days'
    GROUP BY d.merchant_id, dispute_date
),
rolling AS (
    SELECT
        dt.merchant_id,
        dt.txn_date,
        SUM(dt.captures_count)  OVER w AS rolling_captures,
        SUM(dd.dispute_count)   OVER w AS rolling_disputes,
        SUM(dt.gross_paise)     OVER w AS rolling_gross_paise
    FROM daily_txns dt
    LEFT JOIN daily_disputes dd
           ON dd.merchant_id = dt.merchant_id
          AND dd.dispute_date = dt.txn_date
    WINDOW w AS (
        PARTITION BY dt.merchant_id
        ORDER BY dt.txn_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW   -- 7-day window
    )
)
SELECT
    m.display_name                                          AS merchant_name,
    r.txn_date,
    r.rolling_captures,
    COALESCE(r.rolling_disputes, 0)                         AS rolling_disputes,
    ROUND(r.rolling_gross_paise / 100.0, 2)                AS rolling_gross_inr,
    ROUND(
        100.0 * COALESCE(r.rolling_disputes, 0)
        / NULLIF(r.rolling_captures, 0),
        2
    )                                                       AS cb_ratio_pct,
    CASE
        WHEN 100.0 * COALESCE(r.rolling_disputes, 0)
             / NULLIF(r.rolling_captures, 0) > 1.0
        THEN '⚠ ALERT'
        ELSE 'OK'
    END                                                     AS cb_status
FROM rolling r
JOIN merchants m ON m.merchant_id = r.merchant_id
WHERE r.txn_date >= CURRENT_DATE - 7
ORDER BY cb_ratio_pct DESC NULLS LAST, m.display_name;


-- -----------------------------------------------------------
-- Q2: Settlement lag analysis
--     How many days between capture and payout per merchant?
-- -----------------------------------------------------------
SELECT
    m.display_name                                          AS merchant_name,
    COUNT(c.capture_id)                                     AS captures,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (c.settled_at - c.captured_at)) / 86400.0
    ), 2)                                                   AS avg_settlement_lag_days,
    ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (c.settled_at - c.captured_at)) / 86400.0
    ))::NUMERIC, 2)                                                   AS median_lag_days,
    ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (c.settled_at - c.captured_at)) / 86400.0
    ))::NUMERIC, 2)                                                   AS p95_lag_days,
    MAX(EXTRACT(EPOCH FROM (c.settled_at - c.captured_at)) / 86400.0)
                                                            AS max_lag_days
FROM captures c
JOIN merchants m ON m.merchant_id = c.merchant_id
WHERE c.status    = 'SETTLED'
  AND c.settled_at IS NOT NULL
  AND c.captured_at >= NOW() - INTERVAL '90 days'
GROUP BY m.merchant_id, m.display_name
HAVING COUNT(c.capture_id) > 10           -- meaningful sample only
ORDER BY avg_settlement_lag_days DESC;


-- -----------------------------------------------------------
-- Q3: GMV and fee revenue by payment method (last 30 days)
-- -----------------------------------------------------------
SELECT
    a.payment_method,
    a.card_network,
    COUNT(c.capture_id)                             AS transaction_count,
    ROUND(SUM(c.capture_amount_paise) / 100.0, 2)  AS gross_inr,
    ROUND(SUM(c.fee_amount_paise)     / 100.0, 2)  AS fee_revenue_inr,
    ROUND(SUM(c.net_amount_paise)     / 100.0, 2)  AS net_to_merchant_inr,
    ROUND(AVG(c.capture_amount_paise) / 100.0, 2)  AS avg_ticket_inr,
    ROUND(
        100.0 * SUM(c.fee_amount_paise)
        / NULLIF(SUM(c.capture_amount_paise), 0),
        2
    )                                               AS effective_mdr_pct
FROM captures c
JOIN authorizations a ON a.auth_id = c.auth_id
WHERE c.captured_at >= NOW() - INTERVAL '30 days'
  AND c.status NOT IN ('FAILED')
GROUP BY a.payment_method, a.card_network
ORDER BY gross_inr DESC;


-- -----------------------------------------------------------
-- Q4: Payout on-time rate per merchant
-- -----------------------------------------------------------
SELECT
    m.display_name                                          AS merchant_name,
    COUNT(p.payout_id)                                      AS total_payouts,
    COUNT(p.payout_id) FILTER (
        WHERE p.status = 'CREDITED'
          AND p.credited_at::DATE <= p.scheduled_for
    )                                                       AS on_time_payouts,
    COUNT(p.payout_id) FILTER (
        WHERE p.status = 'FAILED'
    )                                                       AS failed_payouts,
    ROUND(
        100.0 * COUNT(p.payout_id) FILTER (
            WHERE p.status = 'CREDITED'
              AND p.credited_at::DATE <= p.scheduled_for
        ) / NULLIF(COUNT(p.payout_id), 0),
        1
    )                                                       AS on_time_rate_pct
FROM payouts p
JOIN merchants m ON m.merchant_id = p.merchant_id
WHERE p.created_at >= NOW() - INTERVAL '90 days'
GROUP BY m.merchant_id, m.display_name
ORDER BY on_time_rate_pct ASC;
