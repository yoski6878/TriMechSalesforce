global class WeeklyNeglectedReminderScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        WeeklyNeglectedReminderBatch batch = new WeeklyNeglectedReminderBatch();
        Database.executeBatch(batch, 2000);
    }
}