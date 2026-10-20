/**
 * MerchantDisputeSync.cls
 *
 * Salesforce Apex class that syncs chargeback/dispute data from the
 * MerchantLens PostgreSQL database (via REST API) into Salesforce
 * Cases, allowing the merchant support team to manage disputes
 * entirely from within their CRM workflow.
 *
 * Real-World Impact:
 *   Before this integration, dispute analysts had to toggle between
 *   the internal payments dashboard and Salesforce, duplicating data
 *   entry and introducing reconciliation errors. This class enables a
 *   single-pane-of-glass experience — when a dispute is raised or
 *   escalated in MerchantLens, a Salesforce Case is automatically
 *   created or updated, and SLA timers begin immediately.
 *
 * AutoRABIT relevance:
 *   This class is version-controlled and deployed via AutoRABIT
 *   ARM (Automated Release Management), ensuring all Apex deployments
 *   go through the DevSecOps pipeline with PMD scanning, test coverage
 *   enforcement, and rollback capability.
 */
public with sharing class MerchantDisputeSync {

    private static final String MERCHANTLENS_API_URL =
        System.Label.MerchantLens_API_Endpoint;  // Custom Label — no hardcoded URLs
    private static final String NAMED_CRED =
        'callout:MerchantLens_API';               // Named Credential handles auth securely

    // ─── Data Transfer Objects ────────────────────────────────────────────

    // Field names intentionally mirror the snake_case keys of the MerchantLens JSON
    // API, because JSON.deserialize maps keys to field names one-to-one.
    @SuppressWarnings('PMD.FieldNamingConventions')
    public class DisputeDTO {
        @AuraEnabled public String  disputeId;
        @AuraEnabled public String  merchantId;
        @AuraEnabled public String  merchantName;
        @AuraEnabled public String  status;          // RECEIVED | UNDER_REVIEW | WON | LOST | ARBITRATION
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  currency_code;
        @AuraEnabled public String  reason;
        @AuraEnabled public String  network_reference;
        @AuraEnabled public String  created_at;
        @AuraEnabled public Integer daysOpen;
    }

    // ─── Scheduled Sync ───────────────────────────────────────────────────

    /**
     * Fetches all disputes updated in the last 24 hours from MerchantLens
     * and upserts them as Salesforce Cases.
     * Intended to run via Scheduled Apex (every hour).
     */
    @future(callout=true)
    public static void syncRecentDisputes() {
        List<DisputeDTO> disputes = fetchDisputesFromAPI('/api/v1/disputes?updated_since=24h');
        if (disputes == null || disputes.isEmpty()) {
            return;
        }
        upsertDisputesAsCases(disputes);
    }

    // ─── Callout ──────────────────────────────────────────────────────────

    private static List<DisputeDTO> fetchDisputesFromAPI(String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(10000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.ERROR,
                'MerchantLens API error: ' + res.getStatus() + ' — ' + res.getBody());
            return null;
        }

        List<DisputeDTO> disputes = (List<DisputeDTO>)
            JSON.deserialize(res.getBody(), List<DisputeDTO>.class);
        return disputes;
    }

    // ─── Upsert Logic ────────────────────────────────────────────────────

    @TestVisible
    private static void upsertDisputesAsCases(List<DisputeDTO> disputes) {
        List<Case> casesToUpsert = new List<Case>();

        for (DisputeDTO d : disputes) {
            Case c = new Case();
            c.Subject           = 'Chargeback — ' + d.merchantName + ' — ' + d.network_reference;
            c.Description       = buildDescription(d);
            c.Origin            = 'MerchantLens';
            c.Status            = mapDisputeStatusToCaseStatus(d.status);
            c.Priority          = d.daysOpen > 5 ? 'High' : 'Medium';
            c.Type              = 'Chargeback';
            c.MerchantLens_Dispute_ID__c = d.disputeId;   // External ID field
            c.Dispute_Amount__c          = d.amount;
            c.Dispute_Currency__c        = d.currency_code;

            casesToUpsert.add(c);
        }

        if (!casesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(
                casesToUpsert,
                Case.MerchantLens_Dispute_ID__c,  // External ID for idempotent upsert
                false                              // allOrNone = false (partial success OK)
            );
            logUpsertErrors(results);
        }
    }

    // ─── Status Mapping ────────────────────────────────────────────────────

    private static String mapDisputeStatusToCaseStatus(String disputeStatus) {
        Map<String, String> statusMap = new Map<String, String>{
            'RECEIVED'      => 'New',
            'UNDER_REVIEW'  => 'In Progress',
            'WON'           => 'Closed',
            'LOST'          => 'Closed',
            'ARBITRATION'   => 'Escalated'
        };
        return statusMap.containsKey(disputeStatus) ? statusMap.get(disputeStatus) : 'New';
    }

    // ─── Helpers ─────────────────────────────────────────────────────────

    private static String buildDescription(DisputeDTO d) {
        return String.format(
            'Dispute ID: {0}\nMerchant: {1} (ID: {2})\nAmount: {3} {4}\n' +
            'Reason: {5}\nNetwork Ref: {6}\nDays Open: {7}\nStatus: {8}',
            new List<Object>{
                d.disputeId, d.merchantName, d.merchantId,
                d.amount, d.currency_code,
                d.reason, d.network_reference, d.daysOpen, d.status
            }
        );
    }

    private static void logUpsertErrors(Database.UpsertResult[] results) {
        for (Database.UpsertResult r : results) {
            if (!r.isSuccess()) {
                for (Database.Error e : r.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Upsert error: ' + e.getMessage() + ' — Fields: ' + e.getFields());
                }
            }
        }
    }

    // ─── Invocable (Flow / Process Builder trigger point) ─────────────────

    /**
     * Allows Salesforce Flow to trigger an on-demand sync for a specific
     * merchant — e.g. when a support agent opens a merchant record.
     */
    @InvocableMethod(label='Sync Merchant Disputes from MerchantLens'
                     description='Fetches latest disputes for a merchant ID and upserts as Cases')
    public static void syncForMerchant(List<String> merchantIds) {
        for (String merchantId : merchantIds) {
            fetchAndSyncMerchant(merchantId);
        }
    }

    @future(callout=true)
    private static void fetchAndSyncMerchant(String merchantId) {
        List<DisputeDTO> disputes =
            fetchDisputesFromAPI('/api/v1/disputes?merchant_id=' + merchantId);
        if (disputes != null) {
            upsertDisputesAsCases(disputes);
        }
    }
}
