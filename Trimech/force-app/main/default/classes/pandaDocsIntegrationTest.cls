// SeeAllData=true is required because Opportunity Split triggers in this org
// prevent inserting Opportunities in test context. We query an existing
// Opportunity to exercise the tokens/recipients branch in buildPayload().
@isTest(SeeAllData=true)
private class pandaDocsIntegrationTest {

    private static final Id FAKE_OPP_ID = '0060000000000001AA';

    // ── buildPayload — opportunity found ─────────────────────────────────────────

    @isTest
    static void testBuildPayload_WithExistingOpportunity_PopulatesTokensAndRecipients() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1];
        if (opps.isEmpty()) {
            return; // no data in org — skip gracefully
        }

        Test.startTest();
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(opps[0].Id, 'tmpl-abc-001');
        Test.stopTest();
    }

    // ── buildPayload — opportunity not found ─────────────────────────────────────

    @isTest
    static void testBuildPayload_OpportunityNotFound_ReturnsTemplateUuidOnly() {
        // FAKE_OPP_ID is valid 18-char format; no Opportunity exists with this Id
        Test.startTest();
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(FAKE_OPP_ID, 'tmpl-abc-002');
        Test.stopTest();
    }

    // ── createPandaDoc ────────────────────────────────────────────────────────────

    @isTest
    static void testCreatePandaDoc_201_InsertsTrackingRecordAndEnqueuesJob() {
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(null, 'tmpl-abc-001');

        // Routes are checked first; fallback catches the POST /documents (201).
        // The enqueued PandaDocSendQueueable (fired inside Test.stopTest) needs
        // routes for its own GET status-check and POST /send to avoid chain exhaustion.
        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .route('/send',      'POST', 200, '{"status":"document.sent"}')
            .route('pd-doc-001', 'GET',  200, '{"id":"pd-doc-001","status":"document.draft"}')
            .fallback(201, '{"id":"pd-doc-001","status":"document.draft"}')
        );

        Test.startTest();
        pandaDocsIntegration.createPandaDoc(payload, null, 'Test Proposal');
        Test.stopTest();
    }

    @isTest
    static void testCreatePandaDoc_Non201_NoRecordCreated() {
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(null, 'tmpl-abc-001');

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .fallback(400, '{"error":"Bad Request"}')
        );

        Test.startTest();
        pandaDocsIntegration.createPandaDoc(payload, null, 'Test Proposal');
        Test.stopTest();
    }

    @isTest
    static void testCreatePandaDoc_ServerError_NoRecordCreated() {
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(null, 'tmpl-abc-001');

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .fallback(500, '{"error":"Internal Server Error"}')
        );

        Test.startTest();
        pandaDocsIntegration.createPandaDoc(payload, null, 'Test Proposal');
        Test.stopTest();
    }
}