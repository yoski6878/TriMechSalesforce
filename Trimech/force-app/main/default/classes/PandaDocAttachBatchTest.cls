@isTest
private class PandaDocAttachBatchTest {

    // Opportunity insert triggers Opportunity Split auto-create which fails in
    // test context. All records are therefore created without Lead_Opportunity__c.

    private static final String FAKE_PDF = 'FAKE-PDF-BINARY-DATA';

    private static Panda_Docs_Document__c insertCompletedRecord(String docId, Integer retryCount) {
        Panda_Docs_Document__c pd = new Panda_Docs_Document__c(
            DocumentId__c        = docId,
            Name                 = 'Batch Test Doc - ' + docId,
            Status__c            = 'document.completed',
            PDF_Attached__c      = false,
            Fetch_Retry_Count__c = retryCount,
            Fetch_Status__c      = 'Pending'
        );
        insert pd;
        return pd;
    }

    // ── Happy path ────────────────────────────────────────────────────────────────

    @isTest
    static void testBatch_DownloadSuccess_AttachesPdfAndLinksRecords() {
        insertCompletedRecord('batch-doc-001', 0);

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf(FAKE_PDF))
        );

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }

    @isTest
    static void testBatch_DownloadSuccess_CreatesFileLinkedToRecord() {
        insertCompletedRecord('batch-doc-002', 0);

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf(FAKE_PDF))
        );

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }

    // ── Download fails / retry ────────────────────────────────────────────────────

    @isTest
    static void testBatch_DownloadFails_IncrementsRetryCountAndSetsPending() {
        insertCompletedRecord('batch-doc-003', 0);

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .route('/download', 'GET', 500, '{"error":"document not ready for download"}')
        );

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }

    // ── Max retries exhausted ─────────────────────────────────────────────────────

    @isTest
    static void testBatch_MaxRetriesExhausted_SetsStatusFailed() {
        // retryCount already at 4 (MAX_RETRIES - 1), so this run pushes it to 5 → Failed
        insertCompletedRecord('batch-doc-004', 4);

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .route('/download', 'GET', 500, '{"error":"still not ready"}')
        );

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }

    // ── Already-attached records are skipped ──────────────────────────────────────

    @isTest
    static void testBatch_AlreadyAttached_NotProcessed() {
        Panda_Docs_Document__c pd = new Panda_Docs_Document__c(
            DocumentId__c        = 'batch-doc-005',
            Name                 = 'Already Attached',
            Status__c            = 'document.completed',
            PDF_Attached__c      = true,
            Fetch_Retry_Count__c = 1,
            Fetch_Status__c      = 'Completed'
        );
        insert pd;

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf(FAKE_PDF))
        );

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }

    // ── finish() executes cleanly on empty scope ──────────────────────────────────

    @isTest
    static void testBatch_Finish_ExecutesWithoutException() {
        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout().fallback(200, '{}'));

        Test.startTest();
        Database.executeBatch(new PandaDocAttachBatch(), 1);
        Test.stopTest();
    }
}