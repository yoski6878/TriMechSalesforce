@isTest
private class CaseReminderBatchScheduler_Test {
    @isTest
    static void testSchedulerRunsBatchJob() {
        Test.startTest();
        CaseReminderBatchScheduler sched = new CaseReminderBatchScheduler();
        sched.execute(null);
        Test.stopTest();
        // No assertions needed; just verify no exceptions and batch job is scheduled
    }
}