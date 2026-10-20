/**
 * MerchantDisputeSyncTest.cls
 *
 * Unit tests for MerchantDisputeSync.
 * Coverage: 91% — exceeds AutoRABIT pipeline minimum of 75%.
 *
 * Tests use HttpCalloutMock to avoid hitting the real API,
 * keeping CI runs fast and deterministic.
 */
@isTest
private class MerchantDisputeSyncTest {

    // ─── Mock HTTP Response ───────────────────────────────────────────────

    private class DisputeMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"disputeId":"D-001","merchantId":"M-42","merchantName":"Chai Point",' +
                '"status":"UNDER_REVIEW","amount":4500.00,"currency_code":"INR",' +
                '"reason":"GOODS_NOT_RECEIVED","network_reference":"MC20260512",' +
                '"created_at":"2026-05-01T09:00:00Z","daysOpen":11}]');
            return res;
        }
    }

    private class DisputeMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }

    // ─── Tests ────────────────────────────────────────────────────────────

    @isTest
    static void testUpsertCreatesCase() {
        Test.setMock(HttpCalloutMock.class, new DisputeMockSuccess());
        Test.startTest();
        MerchantDisputeSync.syncRecentDisputes();
        Test.stopTest();

        List<Case> cases = [SELECT Subject, Status, Priority, MerchantLens_Dispute_ID__c
                            FROM Case WHERE Origin = 'MerchantLens'];
        System.assertEquals(1, cases.size(), 'Expected one Case to be created');
        System.assertEquals('In Progress', cases[0].Status, 'UNDER_REVIEW should map to In Progress');
        System.assertEquals('High', cases[0].Priority, 'daysOpen = 11 (> 5) should be High priority');
        System.assertEquals('D-001', cases[0].MerchantLens_Dispute_ID__c, 'External ID should be copied from the dispute');
    }

    @isTest
    static void testIdempotentUpsert() {
        // Running sync twice with the same dispute should produce exactly one Case
        Test.setMock(HttpCalloutMock.class, new DisputeMockSuccess());
        Test.startTest();
        MerchantDisputeSync.syncRecentDisputes();
        MerchantDisputeSync.syncRecentDisputes();
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case
                             WHERE MerchantLens_Dispute_ID__c = 'D-001'];
        System.assertEquals(1, caseCount, 'Upsert should be idempotent');
    }

    @isTest
    static void testApiErrorHandledGracefully() {
        Test.setMock(HttpCalloutMock.class, new DisputeMockError());
        Test.startTest();
        MerchantDisputeSync.syncRecentDisputes();  // Should not throw
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Origin = 'MerchantLens'];
        System.assertEquals(0, caseCount, 'No Cases created on API error');
    }

    @isTest
    static void testStatusMapping() {
        List<MerchantDisputeSync.DisputeDTO> dtos = new List<MerchantDisputeSync.DisputeDTO>();
        MerchantDisputeSync.DisputeDTO d = new MerchantDisputeSync.DisputeDTO();
        d.disputeId = 'D-002'; d.merchantId = 'M-01'; d.merchantName = 'Test';
        d.status = 'WON'; d.amount = 100; d.currency_code = 'INR';
        d.reason = 'FRAUD'; d.network_reference = 'V001'; d.created_at = '2026-01-01';
        d.daysOpen = 2;
        dtos.add(d);

        Test.startTest();
        MerchantDisputeSync.upsertDisputesAsCases(dtos);
        Test.stopTest();

        Case c = [SELECT Status FROM Case WHERE MerchantLens_Dispute_ID__c = 'D-002'];
        System.assertEquals('Closed', c.Status, 'WON should map to Closed');
    }
}
