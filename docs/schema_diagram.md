# Schema Diagram - MerchantLens

14 tables and 12 enum types, defined in `schema/01_enums.sql` to `schema/05_disputes.sql`. For how the tables are
used (triggers, settlement, fees), see [ARCHITECTURE.md](ARCHITECTURE.md).

## Entity Relationship Overview

```
merchants (1) ──────────────────────────── (N) merchant_bank_accounts
    │                                                  │
    │                                                  └── (N) payouts
    │
    ├── (N) terminals
    │       │
    │       └── (N) authorizations
    │                   │
    │                   └── (N) captures ──── (N) refunds
    │                               │               │
    │                               ├── (N) settlement_line_items ──┘   (credit line per capture,
    │                               │           │                      debit line per refund)
    │                               │    settlement_batches (1) ──── (N) captures
    │                               │           │
    │                               │           ├── (1) payouts         (one payout per batch)
    │                               │           └── (N) reconciliation_mismatches ── captures
    │                               │
    │                               └── (N) disputes
    │                                       │
    │                                       └── (N) dispute_evidence
    │
    ├── (N) settlement_batches
    └── (N) fee_config

audit_log   (standalone: stores table name and record id as text, so it has no foreign keys)
```

A rendered version of the same relationships is in [ARCHITECTURE.md](ARCHITECTURE.md#3-data-model).

## Table Descriptions

The **Design-scale rows** column is the sizing the schema was designed around. It is not what the repository
contains: the bundled seed in `seed/01_seed_data.sql` loads about 60 rows across 8 tables.

| Table | Design-scale rows | Purpose |
|---|---|---|
| `merchants` | ~10K | Business entities onboarded to accept payments |
| `merchant_bank_accounts` | ~12K | Bank accounts for settlement payouts |
| `terminals` | ~100K | Physical/virtual acceptance devices |
| `fee_config` | ~50K | MDR/interchange rate configurations |
| `authorizations` | ~500M | Payment reservations from card networks |
| `captures` | ~490M | Actual fund movements |
| `refunds` | ~20M | Reversal of captures |
| `settlement_batches` | ~5M | Daily/T+N groupings of captures |
| `settlement_line_items` | ~500M | One row per capture or refund in a batch |
| `payouts` | ~5M | NEFT/IMPS credits to merchant banks |
| `reconciliation_mismatches` | ~100K | Discrepancies vs. network files |
| `disputes` | ~10M | Chargebacks filed by cardholders |
| `dispute_evidence` | ~30M | Supporting documents for dispute defense |
| `audit_log` | ~2B | Append-only change history (by convention; see below) |

## Key Relationships

All 22 foreign keys, grouped by the table that owns them:

- **Merchant setup:** `merchant_bank_accounts.merchant_id`, `terminals.merchant_id` and `fee_config.merchant_id`
  → `merchants`
- **Payment flow:** `authorizations.merchant_id` → `merchants`; `authorizations.terminal_id` → `terminals`;
  `captures.auth_id` → `authorizations`; `captures.merchant_id` → `merchants`;
  `refunds.capture_id` → `captures`; `refunds.merchant_id` → `merchants`
- **Settlement:** `captures.settlement_batch_id` → `settlement_batches`;
  `settlement_batches.merchant_id` → `merchants`;
  `settlement_line_items.batch_id` → `settlement_batches`;
  `settlement_line_items.capture_id` → `captures`; `settlement_line_items.refund_id` → `refunds`;
  `payouts.batch_id` → `settlement_batches` (UNIQUE: one payout per batch);
  `payouts.merchant_id` → `merchants`; `payouts.bank_account_id` → `merchant_bank_accounts`;
  `reconciliation_mismatches.batch_id` → `settlement_batches`;
  `reconciliation_mismatches.capture_id` → `captures`
- **Disputes:** `disputes.capture_id` → `captures`; `disputes.merchant_id` → `merchants`;
  `dispute_evidence.dispute_id` → `disputes`

## Design Principles

1. **All monetary values in paise** (integer arithmetic, no floating point errors)
2. **UUIDs for primary keys** (safe for distributed ID generation), except `audit_log`, which uses a `BIGSERIAL`
   because it is an append-only sequence
3. **Timestamps as TIMESTAMPTZ** (stored as UTC; reporting indexes and queries use the `Asia/Kolkata` zone)
4. **Soft deletes via `is_active`** for merchants and terminals
5. **Generated columns** for computed amounts (`captures.net_amount_paise`, `settlement_batches.net_payable_paise`,
   `reconciliation_mismatches.delta_paise`)
6. **Domain enums** for status fields (database-enforced, self-documenting); `dispute_evidence.evidence_type` uses a
   `CHECK` list instead

## Notes on `audit_log`

`audit_log` is written only by the `fn_audit_log` trigger and is meant to be append-only. That is a convention,
not an enforced rule: nothing in the schema revokes `UPDATE` or `DELETE` on it. The trigger is attached to six
tables (`authorizations`, `captures`, `refunds`, `settlement_batches`, `payouts`, `disputes`).
