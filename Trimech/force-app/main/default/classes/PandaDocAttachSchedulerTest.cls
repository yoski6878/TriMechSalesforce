@isTest
private class PandaDocAttachSchedulerTest {

    @isTest
    static void testSchedulerExecutesBatch() {
        Panda_Docs_Document__c pd = new Panda_Docs_Document__c(
            DocumentId__c        = 'sched-doc-001',
            Name                 = 'Scheduler Test Doc',
            Status__c            = 'document.completed',
            PDF_Attached__c      = false,
            Fetch_Retry_Count__c = 0,
            Fetch_Status__c      = 'Pending'
        );
        insert pd;

        Test.setMock(HttpCalloutMock.class, new PandaDocMockCallout()
            .routeBlob('/download', 'GET', 200, Blob.valueOf('SCHEDULER-PDF'))
        );

        Test.startTest();
        System.schedule(
            'PandaDoc Scheduler Test',
            '0 0 * * * ?',
            new PandaDocAttachScheduler()
        );
        Test.stopTest();
    }

    @isTest
    static void testSchedulerJobIsCreated() {
        Test.startTest();
        System.schedule(
            'PandaDoc Scheduler Job Test',
            '0 0 * * * ?',
            new PandaDocAttachScheduler()
        );
        Test.stopTest();
    }
}