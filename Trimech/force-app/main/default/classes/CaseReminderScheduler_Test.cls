@isTest
private class CaseReminderScheduler_Test {
    @isTest
    static void testScheduleReminderJob() {
        // Mock CaseReminderJob to avoid side effects
        Test.startTest();
        // Call the scheduler method
        CaseReminderScheduler.scheduleReminderJob();
        Test.stopTest();
        // Assert that a scheduled job exists
        List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, State FROM CronTrigger WHERE CronJobDetail.Name = 'CaseReminder_Hourly' AND State = 'WAITING'];
        System.assert(!jobs.isEmpty(), 'Scheduled job should exist');
    }
}