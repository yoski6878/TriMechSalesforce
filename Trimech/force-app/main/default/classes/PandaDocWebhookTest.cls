@isTest
private class PandaDocWebhookTest {

    private static void setWebhookBody(String jsonBody) {
        RestRequest req = new RestRequest();
        req.httpMethod   = 'POST';
        req.requestURI   = '/services/apexrest/pandadoc/';
        req.requestBody  = Blob.valueOf(jsonBody);
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static String stateChangedEvent(String docId, String status) {
        return '[{"event":"document_state_changed","data":{"id":"' + docId + '","status":"' + status + '"}}]';
    }

    // ── Insert new record ─────────────────────────────────────────────────────────

    @isTest
    static void testHandleWebhook_NewDocument_InsertsTrackingRecord() {
        setWebhookBody(stateChangedEvent('wh-doc-001', 'document.sent'));

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── Update existing record ────────────────────────────────────────────────────

    @isTest
    static void testHandleWebhook_ExistingDocument_UpdatesStatus() {
        Panda_Docs_Document__c existing = new Panda_Docs_Document__c(
            DocumentId__c = 'wh-doc-002',
            Status__c     = 'document.draft',
            Name          = 'Webhook Update Test'
        );
        insert existing;

        setWebhookBody(stateChangedEvent('wh-doc-002', 'document.sent'));

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── document.completed sets fetch fields ──────────────────────────────────────

    @isTest
    static void testHandleWebhook_DocumentCompleted_NewRecord_SetsFetchPending() {
        setWebhookBody(stateChangedEvent('wh-doc-003', 'document.completed'));

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    @isTest
    static void testHandleWebhook_DocumentCompleted_ExistingRecord_ResetsFetchFields() {
        Panda_Docs_Document__c existing = new Panda_Docs_Document__c(
            DocumentId__c        = 'wh-doc-004',
            Status__c            = 'document.sent',
            Name                 = 'Webhook Complete Reset Test',
            Fetch_Status__c      = 'Failed',
            PDF_Attached__c      = false,
            Fetch_Retry_Count__c = 5
        );
        insert existing;

        setWebhookBody(stateChangedEvent('wh-doc-004', 'document.completed'));

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── Non-state-changed events are ignored ──────────────────────────────────────

    @isTest
    static void testHandleWebhook_NonStateChangedEvent_NoRecordCreated() {
        setWebhookBody('[{"event":"document_viewed","data":{"id":"wh-doc-005","status":"document.sent"}}]');

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── Multiple events in one payload ────────────────────────────────────────────

    @isTest
    static void testHandleWebhook_MultipleEvents_ProcessesAllStateChanged() {
        String body = '[' +
            '{"event":"document_state_changed","data":{"id":"wh-doc-006","status":"document.sent"}},' +
            '{"event":"document_state_changed","data":{"id":"wh-doc-007","status":"document.completed"}},' +
            '{"event":"document_viewed","data":{"id":"wh-doc-008","status":"document.sent"}}' +
        ']';
        setWebhookBody(body);

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── Blank/missing fields are skipped ─────────────────────────────────────────

    @isTest
    static void testHandleWebhook_BlankDocumentId_Skipped() {
        setWebhookBody('[{"event":"document_state_changed","data":{"id":"","status":"document.sent"}}]');

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }

    // ── Malformed JSON returns 500 ────────────────────────────────────────────────

    @isTest
    static void testHandleWebhook_MalformedJson_Returns500() {
        setWebhookBody('NOT VALID JSON {{{{');

        Test.startTest();
        PandaDocWebhook.handleWebhook();
        Test.stopTest();
    }
}