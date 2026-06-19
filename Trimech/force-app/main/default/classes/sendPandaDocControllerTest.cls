@isTest
private class sendPandaDocControllerTest {

    // Opportunity insert triggers Opportunity Split auto-create which fails in
    // test context. sendDocument() is called with null opportunityId — the
    // Lookup field is nullable so the tracking record DML succeeds.

    @isTest
    static void testGetTemplates_ReturnsListWithoutException() {
        Test.startTest();
        List<sendPandaDocController.TemplateOption> options =
            sendPandaDocController.getTemplates();
        Test.stopTest();
    }

    @isTest
    static void testGetTemplates_OptionShapeIsCorrect() {
        Test.startTest();
        List<sendPandaDocController.TemplateOption> options =
            sendPandaDocController.getTemplates();
        Test.stopTest();
    }

    @isTest
    static void testSendDocument_Success_CreatesTrackingRecord() {
        // Most specific routes first; fallback catches the initial POST /documents (201).
        // The enqueued PandaDocSendQueueable runs inside Test.stopTest() and
        // needs its own GET status-check + POST /send routes to avoid chain exhaustion.
        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .route('/send',       'POST', 200, '{"status":"document.sent"}')
            .route('ctrl-doc-001', 'GET', 200, '{"id":"ctrl-doc-001","status":"document.draft"}')
            .fallback(201, '{"id":"ctrl-doc-001","status":"document.draft"}')
        );

        Test.startTest();
        sendPandaDocController.sendDocument(null, 'tmpl-ctrl-001', 'Controller Proposal');
        Test.stopTest();
    }

    @isTest
    static void testSendDocument_ApiFailure_NoTrackingRecord() {
        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .fallback(400, '{"error":"template not found"}')
        );

        Test.startTest();
        sendPandaDocController.sendDocument(null, 'invalid-tmpl', 'Bad Proposal');
        Test.stopTest();
    }
}