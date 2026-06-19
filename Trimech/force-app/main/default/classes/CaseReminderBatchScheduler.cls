public with sharing class CaseReminderBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CaseReminderBatchJob(), 25);
    }
}