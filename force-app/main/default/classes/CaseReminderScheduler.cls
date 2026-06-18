public with sharing class CaseReminderScheduler {
    /**
     * Schedules a single recurring Case Reminder job to run every hour
     */
    public static void scheduleReminderJob() {
        String jobName = 'CaseReminder_Hourly';
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :jobName AND State = 'WAITING'];
        for (CronTrigger job : jobs) {
            System.abortJob(job.Id);
        }
        // Schedule the job to run every hour
        String cron = '0 0 * * * ?';
        System.schedule(jobName, cron, new CaseReminderJob());
    }
}