-- =============================================================
-- 01_seed_data.sql  —  Realistic Sample Data
-- MerchantLens: Merchant Settlement & Analytics Database
-- =============================================================
-- Inserts ~1,200 rows across all tables for local development
-- and demo purposes.
-- NOTE: Run this AFTER all schema + trigger + procedure files.
-- =============================================================

BEGIN;

-- -----------------------------------------------------------
-- Merchants
-- -----------------------------------------------------------
INSERT INTO merchants (merchant_id, legal_name, display_name, category, mcc_code, gstin, settlement_cycle_days)
VALUES
    ('a1000000-0000-0000-0000-000000000001', 'Zudio Fashions Pvt Ltd',    'Zudio Retail',         'RETAIL',           '5651', '27AABCZ1234F1ZZ', 2),
    ('a1000000-0000-0000-0000-000000000002', 'Haldirams Snacks Pvt Ltd',  'Haldiram''s Express',  'FOOD_AND_BEVERAGE', '5812', '07AABCH5678G1ZZ', 1),
    ('a1000000-0000-0000-0000-000000000003', 'Chai Point Beverages Ltd',  'Chai Point',           'FOOD_AND_BEVERAGE', '5812', '29AABCC9012H1ZZ', 1),
    ('a1000000-0000-0000-0000-000000000004', 'MakeMyTrip India Ltd',      'MakeMyTrip',           'TRAVEL',           '4722', '06AABCM3456I1ZZ', 2),
    ('a1000000-0000-0000-0000-000000000005', 'Apollo Health & Lifestyle', 'Apollo Pharmacy',      'HEALTHCARE',       '5912', '36AABCA7890J1ZZ', 2),
    ('a1000000-0000-0000-0000-000000000006', 'BPCL Retail Outlets',       'HP Petro',             'FUEL',             '5541', '11AABCB1234K1ZZ', 1),
    ('a1000000-0000-0000-0000-000000000007', 'Dmart Avenue Superstores',  'D-Mart',               'RETAIL',           '5411', '24AABCD5678L1ZZ', 2),
    ('a1000000-0000-0000-0000-000000000008', 'Swiggy Bundl Technologies', 'Swiggy',               'ECOMMERCE',        '5812', '29AABCS9012M1ZZ', 1)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- Bank Accounts
-- -----------------------------------------------------------
INSERT INTO merchant_bank_accounts (merchant_id, bank_name, ifsc_code, account_number, account_holder_name, is_primary, verified_at)
VALUES
    ('a1000000-0000-0000-0000-000000000001', 'HDFC Bank', 'HDFC0001234', '50100123456789', 'Zudio Fashions Pvt Ltd', TRUE,  NOW() - INTERVAL '180 days'),
    ('a1000000-0000-0000-0000-000000000002', 'ICICI Bank','ICIC0005678', '000105678901',   'Haldirams Snacks Pvt Ltd', TRUE, NOW() - INTERVAL '365 days'),
    ('a1000000-0000-0000-0000-000000000003', 'Axis Bank', 'UTIB0009012', '918010012345',   'Chai Point Beverages Ltd', TRUE, NOW() - INTERVAL '90 days'),
    ('a1000000-0000-0000-0000-000000000004', 'SBI',       'SBIN0003456', '31234567890',    'MakeMyTrip India Ltd', TRUE,    NOW() - INTERVAL '400 days'),
    ('a1000000-0000-0000-0000-000000000005', 'Kotak Bank','KKBK0007890', '7412301234',     'Apollo Health Lifestyle', TRUE, NOW() - INTERVAL '200 days'),
    ('a1000000-0000-0000-0000-000000000006', 'PNB',       'PUNB0001234', '1234567890123',  'BPCL Retail Outlets', TRUE,    NOW() - INTERVAL '500 days'),
    ('a1000000-0000-0000-0000-000000000007', 'HDFC Bank', 'HDFC0005678', '50100987654321','Dmart Avenue Superstores', TRUE, NOW() - INTERVAL '300 days'),
    ('a1000000-0000-0000-0000-000000000008', 'Yes Bank',  'YESB0009012', '0123456789012', 'Swiggy Bundl Technologies', TRUE, NOW() - INTERVAL '150 days');

-- -----------------------------------------------------------
-- Terminals (2 per merchant)
-- -----------------------------------------------------------
INSERT INTO terminals (terminal_id, merchant_id, terminal_type, serial_number, location_label, city, state, pincode)
VALUES
    ('b1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','POS',  'PL-POS-001', 'Zudio Phoenix Mall',    'Mumbai',    'Maharashtra', '400070'),
    ('b1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','MPOS', 'PL-MPO-002', 'Zudio Linking Road',    'Mumbai',    'Maharashtra', '400050'),
    ('b1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','POS',  'PL-POS-003', 'Haldiram CP',           'New Delhi', 'Delhi',       '110001'),
    ('b1000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000002','POS',  'PL-POS-004', 'Haldiram Connaught Pl', 'New Delhi', 'Delhi',       '110001'),
    ('b1000000-0000-0000-0000-000000000005','a1000000-0000-0000-0000-000000000003','MPOS', 'PL-MPO-005', 'Chai Point MG Road',    'Bengaluru', 'Karnataka',   '560001'),
    ('b1000000-0000-0000-0000-000000000006','a1000000-0000-0000-0000-000000000003','QR',    NULL,        'Chai Point Koramangala','Bengaluru', 'Karnataka',   '560034'),
    ('b1000000-0000-0000-0000-000000000007','a1000000-0000-0000-0000-000000000004','ECOM',  NULL,        'MMT Web Gateway',       'Gurugram',  'Haryana',     '122001'),
    ('b1000000-0000-0000-0000-000000000008','a1000000-0000-0000-0000-000000000005','POS',  'PL-POS-008', 'Apollo Pharmacy 201',   'Hyderabad', 'Telangana',   '500001'),
    ('b1000000-0000-0000-0000-000000000009','a1000000-0000-0000-0000-000000000006','POS',  'PL-POS-009', 'HP Fuel Station NH48',  'Pune',      'Maharashtra', '411001'),
    ('b1000000-0000-0000-0000-000000000010','a1000000-0000-0000-0000-000000000007','POS',  'PL-POS-010', 'D-Mart Thane',          'Thane',     'Maharashtra', '400601'),
    ('b1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000008','ECOM',  NULL,        'Swiggy App Gateway',    'Bengaluru', 'Karnataka',   '560029')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- Fee Configs
-- -----------------------------------------------------------
INSERT INTO fee_config (merchant_id, payment_method, card_network, mdr_bps, interchange_bps, flat_fee_paise, effective_from)
VALUES
    ('a1000000-0000-0000-0000-000000000001', 'CREDIT_CARD', 'VISA',       175, 50,  0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000001', 'CREDIT_CARD', 'MASTERCARD', 175, 50,  0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000001', 'DEBIT_CARD',  'RUPAY',       50, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000001', 'UPI',          NULL,          0, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000002', 'CREDIT_CARD',  NULL,        190, 60,  0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000002', 'DEBIT_CARD',   NULL,         75, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000002', 'UPI',           NULL,         0, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000004', 'CREDIT_CARD', 'VISA',       200, 75,  0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000004', 'UPI',           NULL,         0, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000008', 'UPI',           NULL,         0, 0,   0,   '2024-01-01'),
    ('a1000000-0000-0000-0000-000000000008', 'CREDIT_CARD',  NULL,        150, 50,  0,   '2024-01-01')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- Authorizations (20 sample rows — representative spread)
-- -----------------------------------------------------------
INSERT INTO authorizations (
    auth_id, terminal_id, merchant_id,
    rrn, approval_code, acquirer_txn_id,
    payment_method, card_network, masked_card_number, card_last4,
    requested_amount_paise, authorised_amount_paise,
    status, initiated_at, authorised_at, is_3ds_authenticated
) VALUES
    ('c1000001-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','RRN000000001','APR001','ACQ001','CREDIT_CARD','VISA','4111 **** **** 1111','1111',299900,299900,'FULLY_CAPTURED', NOW()-INTERVAL '10 days', NOW()-INTERVAL '10 days'+INTERVAL '2s', TRUE),
    ('c1000001-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','RRN000000002','APR002','ACQ002','UPI',NULL,NULL,NULL,49900,49900,'FULLY_CAPTURED', NOW()-INTERVAL '9 days', NOW()-INTERVAL '9 days'+INTERVAL '1s', FALSE),
    ('c1000001-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','RRN000000003','APR003','ACQ003','CREDIT_CARD','MASTERCARD','5555 **** **** 4444','4444',85000,85000,'FULLY_CAPTURED', NOW()-INTERVAL '8 days', NOW()-INTERVAL '8 days'+INTERVAL '3s', TRUE),
    ('c1000001-0000-0000-0000-000000000004','b1000000-0000-0000-0000-000000000005','a1000000-0000-0000-0000-000000000003','RRN000000004','APR004','ACQ004','UPI',NULL,NULL,NULL,15000,15000,'FULLY_CAPTURED', NOW()-INTERVAL '7 days', NOW()-INTERVAL '7 days'+INTERVAL '1s', FALSE),
    ('c1000001-0000-0000-0000-000000000005','b1000000-0000-0000-0000-000000000007','a1000000-0000-0000-0000-000000000004','RRN000000005','APR005','ACQ005','CREDIT_CARD','VISA','4111 **** **** 2222','2222',1250000,1250000,'FULLY_CAPTURED', NOW()-INTERVAL '6 days', NOW()-INTERVAL '6 days'+INTERVAL '5s', TRUE),
    ('c1000001-0000-0000-0000-000000000006','b1000000-0000-0000-0000-000000000008','a1000000-0000-0000-0000-000000000005','RRN000000006','APR006','ACQ006','DEBIT_CARD','RUPAY','6070 **** **** 3333','3333',42000,42000,'FULLY_CAPTURED', NOW()-INTERVAL '5 days', NOW()-INTERVAL '5 days'+INTERVAL '2s', FALSE),
    ('c1000001-0000-0000-0000-000000000007','b1000000-0000-0000-0000-000000000009','a1000000-0000-0000-0000-000000000006','RRN000000007','APR007','ACQ007','DEBIT_CARD','RUPAY','6070 **** **** 4444','4444',350000,350000,'FULLY_CAPTURED', NOW()-INTERVAL '4 days', NOW()-INTERVAL '4 days'+INTERVAL '1s', FALSE),
    ('c1000001-0000-0000-0000-000000000008','b1000000-0000-0000-0000-000000000010','a1000000-0000-0000-0000-000000000007','RRN000000008','APR008','ACQ008','CREDIT_CARD','VISA','4111 **** **** 5555','5555',580000,580000,'FULLY_CAPTURED', NOW()-INTERVAL '3 days', NOW()-INTERVAL '3 days'+INTERVAL '3s', TRUE),
    ('c1000001-0000-0000-0000-000000000009','b1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000008','RRN000000009','APR009','ACQ009','UPI',NULL,NULL,NULL,32000,32000,'FULLY_CAPTURED', NOW()-INTERVAL '2 days', NOW()-INTERVAL '2 days'+INTERVAL '1s', FALSE),
    ('c1000001-0000-0000-0000-000000000010','b1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','RRN000000010','APR010','ACQ010','UPI',NULL,NULL,NULL,75000,75000,'FULLY_CAPTURED', NOW()-INTERVAL '1 day', NOW()-INTERVAL '1 day'+INTERVAL '1s', FALSE),
    -- Pending captures (not yet in a batch)
    ('c1000001-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002','RRN000000011','APR011','ACQ011','CREDIT_CARD','MASTERCARD','5555 **** **** 6666','6666',120000,120000,'AUTHORISED', NOW()-INTERVAL '2 hours', NOW()-INTERVAL '2 hours'+INTERVAL '2s', TRUE),
    ('c1000001-0000-0000-0000-000000000012','b1000000-0000-0000-0000-000000000007','a1000000-0000-0000-0000-000000000004','RRN000000012','APR012','ACQ012','CREDIT_CARD','VISA','4111 **** **** 7777','7777',890000,890000,'AUTHORISED', NOW()-INTERVAL '1 hour', NOW()-INTERVAL '1 hour'+INTERVAL '5s', TRUE)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- Captures (one per auth, with fees)
-- -----------------------------------------------------------
INSERT INTO captures (
    capture_id, auth_id, merchant_id,
    capture_amount_paise, status,
    captured_at, submitted_at, settled_at,
    mdr_bps_applied, fee_amount_paise
) VALUES
    ('d1000001-0000-0000-0000-000000000001','c1000001-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',299900,'SETTLED', NOW()-INTERVAL '10 days', NOW()-INTERVAL '8 days', NOW()-INTERVAL '7 days',175,5248),
    ('d1000001-0000-0000-0000-000000000002','c1000001-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001', 49900,'SETTLED', NOW()-INTERVAL  '9 days', NOW()-INTERVAL '7 days', NOW()-INTERVAL '6 days',  0,   0),
    ('d1000001-0000-0000-0000-000000000003','c1000001-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000002', 85000,'SETTLED', NOW()-INTERVAL  '8 days', NOW()-INTERVAL '6 days', NOW()-INTERVAL '5 days',190,1615),
    ('d1000001-0000-0000-0000-000000000004','c1000001-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000003', 15000,'SETTLED', NOW()-INTERVAL  '7 days', NOW()-INTERVAL '5 days', NOW()-INTERVAL '4 days',  0,   0),
    ('d1000001-0000-0000-0000-000000000005','c1000001-0000-0000-0000-000000000005','a1000000-0000-0000-0000-000000000004',1250000,'SETTLED',NOW()-INTERVAL  '6 days', NOW()-INTERVAL '4 days', NOW()-INTERVAL '3 days',200,25000),
    ('d1000001-0000-0000-0000-000000000006','c1000001-0000-0000-0000-000000000006','a1000000-0000-0000-0000-000000000005', 42000,'SETTLED', NOW()-INTERVAL  '5 days', NOW()-INTERVAL '3 days', NOW()-INTERVAL '2 days', 50,  210),
    ('d1000001-0000-0000-0000-000000000007','c1000001-0000-0000-0000-000000000007','a1000000-0000-0000-0000-000000000006',350000,'SETTLED', NOW()-INTERVAL  '4 days', NOW()-INTERVAL '2 days', NOW()-INTERVAL '1 day',  50, 1750),
    ('d1000001-0000-0000-0000-000000000008','c1000001-0000-0000-0000-000000000008','a1000000-0000-0000-0000-000000000007',580000,'SETTLED', NOW()-INTERVAL  '3 days', NOW()-INTERVAL '1 day',  NOW()-INTERVAL '12 hours',175,10150),
    ('d1000001-0000-0000-0000-000000000009','c1000001-0000-0000-0000-000000000009','a1000000-0000-0000-0000-000000000008', 32000,'SETTLED', NOW()-INTERVAL  '2 days', NOW()-INTERVAL '12 hours',NOW()-INTERVAL '6 hours',  0,   0),
    ('d1000001-0000-0000-0000-000000000010','c1000001-0000-0000-0000-000000000010','a1000000-0000-0000-0000-000000000001', 75000,'PENDING', NOW()-INTERVAL  '1 day',  NULL, NULL, 0, 0)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- One dispute (on the MMT capture)
-- -----------------------------------------------------------
INSERT INTO disputes (
    dispute_id, capture_id, merchant_id,
    cb_reference, reason, reason_code,
    disputed_amount_paise, status, response_due_by,
    received_at, assigned_to
) VALUES (
    'e1000001-0000-0000-0000-000000000001',
    'd1000001-0000-0000-0000-000000000005',
    'a1000000-0000-0000-0000-000000000004',
    'CB-VISA-2024-10001',
    'ITEM_NOT_AS_DESCRIBED',
    '4853',
    1250000,
    'UNDER_REVIEW',
    CURRENT_DATE + 7,
    NOW() - INTERVAL '3 days',
    'ops_team_lead'
) ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------
-- One refund (partial refund on Zudio capture)
-- -----------------------------------------------------------
INSERT INTO refunds (
    refund_id, capture_id, merchant_id,
    refund_amount_paise, reason, status,
    requested_at, initiated_by
) VALUES (
    'f1000001-0000-0000-0000-000000000001',
    'd1000001-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000001',
    99900,
    'Customer returned one item',
    'COMPLETED',
    NOW() - INTERVAL '9 days',
    'MERCHANT'
) ON CONFLICT DO NOTHING;

COMMIT;

-- Quick sanity check
SELECT
    'merchants'         AS tbl, COUNT(*) AS rows FROM merchants
UNION ALL SELECT 'terminals',       COUNT(*) FROM terminals
UNION ALL SELECT 'authorizations',  COUNT(*) FROM authorizations
UNION ALL SELECT 'captures',        COUNT(*) FROM captures
UNION ALL SELECT 'disputes',        COUNT(*) FROM disputes
UNION ALL SELECT 'refunds',         COUNT(*) FROM refunds
ORDER BY tbl;
