# MerchantLens: Merchant Settlement & Analytics Database

A PostgreSQL project for payment settlement reconciliation, merchant analytics and chargeback lifecycle management, with a small Java REST API, a Salesforce Apex sync and a CI/CD pipeline around it.

All data in this repository is **synthetic seed data** generated for the project. Nothing here has processed real payments.

## What problem it explores

Settlement and chargeback work in payments tends to fail in the same few places. This project builds a small version of each fix:

| Problem | What MerchantLens does |
|---|---|
| Chargeback status can be changed to an invalid state | A `BEFORE UPDATE` trigger enforces the lifecycle `RECEIVED → UNDER_REVIEW → WON / LOST / ARBITRATION`, so no service or manual `psql` session can skip a step |
| No record of who changed financial data | A trigger-based audit log on the financial tables, written by the database rather than by application code |
| Chargeback ratios only noticed at month end | A rolling 7-day chargeback-ratio query per merchant with an alert flag |
| Dispute analysts switching between tools | An Apex class syncs disputes into Salesforce Cases; a dispute reaching `ARBITRATION` raises the linked Case to `Escalated` |
| Direct database access from other systems | A Spring Boot API sits in front of the database with JWT authentication and response DTOs, so internal entities are not exposed |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions CI/CD                         │
│  Secret Scan → SAST → DB Validate → Java Test → SF Validate     │
│              → DAST (main) → Deploy                              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │   Java Spring Boot API      │  ← JWT auth, security headers
         │   (DisputeController, etc.) │
         └──────┬──────────┬──────────┘
                │          │
   ┌────────────▼──┐  ┌────▼────────────────┐
   │  PostgreSQL   │  │  Salesforce          │
   │  MerchantLens │  │  (Apex callout sync) │
   │  DB           │  │  Cases               │
   └───────────────┘  └─────────────────────┘
```

## Project structure

```
pine-settlement-db/
├── .github/workflows/
│   └── devsecops-pipeline.yml    # 7-stage CI/CD pipeline
├── schema/                       # PostgreSQL schema (12 tables, normalized to 3NF)
├── indexes/                      # Composite, partial and expression indexes
├── triggers/                     # Audit log + chargeback lifecycle trigger
├── procedures/                   # Settlement run, dispute escalation, fee calculation
├── queries/                      # Reconciliation, analytics, cohorts
├── seed/                         # 1,000+ rows of synthetic seed data
├── java-api/                     # Spring Boot REST API
│   └── src/main/java/com/merchantlens/
│       ├── controller/DisputeController.java   # Dispute endpoints
│       ├── service/DisputeService.java         # Business logic, database calls
│       ├── model/DisputeResponse.java          # Response DTO
│       └── security/SecurityConfig.java        # JWT, CORS, HSTS
├── salesforce/force-app/main/default/classes/
│   ├── MerchantDisputeSync.cls       # Apex callout → Salesforce Cases
│   └── MerchantDisputeSyncTest.cls   # Apex tests with mock callouts
├── devsecops/db_tests.sql            # pgTAP tests used by the CI database stage
└── docs/schema_diagram.md            # Entity relationship description
```

## The database

- **Schema:** 12 normalized tables covering merchants, transactions, settlements, fees and disputes.
- **Indexes:** composite, partial and expression indexes for the reconciliation and analytics queries.
- **Triggers:** the chargeback lifecycle trigger and the audit-log trigger.
- **Procedures (PL/pgSQL):** settlement run, dispute escalation, MDR fee calculation.
- **Analytics queries:** reconciliation, settlement lag, merchant cohorts, and the rolling 7-day chargeback ratio, written with CTEs and window functions.

### Sample output

Illustrative output on the synthetic seed data (merchant names and numbers are made up):

```
-- Rolling 7-day chargeback ratio by merchant
merchant_name | txn_count | dispute_count | cb_ratio_pct | alert
--------------+-----------+---------------+--------------+-------
Merchant A    |      4821 |            31 |         0.64 | false
Merchant B    |      2103 |            29 |         1.38 | true
Merchant C    |      1897 |             8 |         0.42 | false
```

## Quick start

### PostgreSQL

```bash
createdb merchantlens

psql -d merchantlens -f schema/01_enums.sql
psql -d merchantlens -f schema/02_core_tables.sql
psql -d merchantlens -f schema/03_transaction.sql
psql -d merchantlens -f schema/04_settlement.sql
psql -d merchantlens -f schema/05_disputes.sql
psql -d merchantlens -f indexes/01_indexes.sql
psql -d merchantlens -f triggers/01_audit_trigger.sql
psql -d merchantlens -f triggers/02_dispute_fsm.sql
psql -d merchantlens -f procedures/01_run_settlement.sql
psql -d merchantlens -f procedures/02_escalate_disputes.sql
psql -d merchantlens -f procedures/03_compute_fees.sql
psql -d merchantlens -f seed/01_seed_data.sql

# Run the analytics
psql -d merchantlens -f queries/02_merchant_analytics.sql
```

### Java API

```bash
cd java-api

# Test profile (H2 in-memory database)
mvn spring-boot:run -Dspring.profiles.active=test

# Against local Postgres
export DB_URL=jdbc:postgresql://localhost:5432/merchantlens
export DB_USER=ml_user
export DB_PASS=yourpassword
mvn spring-boot:run

# Example requests
curl -H "Authorization: Bearer <jwt>" \
     "http://localhost:8080/api/v1/disputes?updated_since=24h"
curl -H "Authorization: Bearer <jwt>" \
     http://localhost:8080/api/v1/disputes/summary
```

### Salesforce

Requires a Salesforce sandbox and a Named Credential that points at the API.

```bash
sf org login web --alias merchantlens-sandbox

sf project deploy start \
  --source-dir salesforce/force-app \
  --target-org merchantlens-sandbox \
  --test-level RunLocalTests
```

`MerchantDisputeSync` syncs disputes into Salesforce Cases on a schedule. When a dispute reaches `ARBITRATION` in the database, the linked Case is updated to `Escalated` priority.

## CI/CD pipeline (7 stages)

```
Push / PR
    │
    ▼
[1] Secret scan          Gitleaks + TruffleHog
    ▼
[2] SAST                 SpotBugs (Java), OWASP Dependency-Check, SQLFluff
    ▼
[3] DB validation        Schema applied to an ephemeral Postgres, pgTAP tests run
    ▼
[4] Java tests           Maven unit + integration tests, JaCoCo ≥ 70% gate
    ▼
[5] Salesforce validate  SF CLI check-only deploy + PMD static analysis of Apex
    ▼
[6] DAST (main only)     OWASP ZAP baseline scan against a staging URL
    ▼
[7] Deploy               DB migrations, Docker image push, Salesforce metadata deploy, Slack notification
```

The pipeline is set up to block a deploy when a stage fails: secret scan, SpotBugs, dependency vulnerabilities at CVSS 7 or above, coverage under 70%, PMD findings at severity 3 or worse, or ZAP findings.

## Design decisions

1. **API in front of the database.** Letting other systems connect straight to the database would mean sharing database credentials and skipping request validation. The API authenticates callers with JWT and returns DTOs, so table structure is not exposed.
2. **Lifecycle rules in a trigger, not application code.** Valid chargeback transitions are enforced by the database itself, so Java, Apex and a manual SQL session are all held to the same rules.
3. **Audit log written by the database.** Because a trigger writes it, changes made through the API, Apex or `psql` are all recorded. A database superuser could still alter the log, so this is an audit trail rather than a tamper-proof one.
4. **Idempotent Salesforce sync.** Cases are upserted on an external ID (`MerchantLens_Dispute_ID__c`), so re-running the sync after a failure does not create duplicate Cases.
5. **Security checks as pipeline gates.** Secret scanning, static analysis, dependency checks and a dynamic scan run before deploy rather than after.

## Scope and limits

- **Synthetic data only.** The seed data is generated; reported figures are not real merchant or payment data.
- **Salesforce sync needs a sandbox.** It requires your own org, a Named Credential and an External ID field on Case, and it is not a hosted demo.
- **DAST and deploy stages need configuration.** The ZAP scan needs a staging URL, and the deploy stage needs your registry, Salesforce and Slack secrets.
- **Rate limiting and rollback are not implemented.** Authentication, CORS and HSTS are in `SecurityConfig`; request throttling and automated rollback would be next steps.
- **Not a production payment system.** It does not handle card data and has not been reviewed against PCI-DSS or RBI requirements.

## Skills demonstrated

| Layer | Skill |
|---|---|
| Database | 12-table normalized schema, CTEs, window functions, PL/pgSQL procedures, triggers, partial indexes |
| Java | Spring Boot REST API, Spring Security (JWT, CORS, HSTS), DTO pattern, JaCoCo coverage gate |
| Salesforce | Apex HTTP callouts, Named Credentials, `with sharing`, mock callouts in tests |
| CI/CD | 7-stage GitHub Actions pipeline, SAST, DAST, pgTAP database tests, secret scanning |
| Domain | Payments reconciliation, chargeback lifecycle, MDR fee computation, settlement lag analytics |
