@isTest
private class PandaDocServiceQueueableTest {

    // Opportunity insert triggers Opportunity Split auto-create which fails in
    // test context. All tests therefore use Panda_Docs_Document__c records
    // without a linked Opportunity (Lead_Opportunity__c = null).

    private static final String FAKE_PDF_CONTENT = 'PDF-BINARY-CONTENT';

    private static Panda_Docs_Document__c insertTrackingRecord(String docId) {
        Panda_Docs_Document__c pd = new Panda_Docs_Document__c(
            DocumentId__c        = docId,
            Name                 = 'Service Test Doc',
            Status__c            = 'document.completed',
            PDF_Attached__c      = false,
            Fetch_Retry_Count__c = 0,
            Fetch_Status__c      = 'Pending'
        );
        insert pd;
        return pd;
    }

    // ── Download success ──────────────────────────────────────────────────────────

    @isTest
    static void testExecute_DownloadSuccess_RunsWithoutException() {
        insertTrackingRecord('svc-q-doc-001');

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf(FAKE_PDF_CONTENT))
        );

        Test.startTest();
        System.enqueueJob(new PandaDocServiceQueueable('svc-q-doc-001'));
        Test.stopTest();
    }

    @isTest
    static void testExecute_DownloadSuccess_SecondRecord_RunsWithoutException() {
        insertTrackingRecord('svc-q-doc-002');

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf(FAKE_PDF_CONTENT))
        );

        Test.startTest();
        System.enqueueJob(new PandaDocServiceQueueable('svc-q-doc-002'));
        Test.stopTest();
    }

    // ── No tracking record ────────────────────────────────────────────────────────

    @isTest
    static void testExecute_NoTrackingRecord_ExitsEarlyWithoutException() {
        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .fallback(200, '{}')
        );

        Test.startTest();
        System.enqueueJob(new PandaDocServiceQueueable('nonexistent-doc-id'));
        Test.stopTest();
    }

    // ── Download fails ────────────────────────────────────────────────────────────

    @isTest
    static void testExecute_DownloadFails_AbortsBeforeInsertingFile() {
        insertTrackingRecord('svc-q-doc-003');

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .route('/download', 'GET', 500, '{"error":"document not ready"}')
        );

        Test.startTest();
        System.enqueueJob(new PandaDocServiceQueueable('svc-q-doc-003'));
        Test.stopTest();
    }
}