// CaseReminderResetTrigger.trigger
// Resets reminder/task checkboxes when a Case leaves 'Waiting for Client'

trigger CaseReminderResetTrigger on Case (before update) {
    for (Case c : Trigger.new) {
        Case oldC = Trigger.oldMap.get(c.Id);
        if (oldC.Status == 'Waiting for Client' && c.Status != 'Waiting for Client') {
            c.X16_Hour_Reminder_Sent__c = false;
            c.X32_Hour_Reminder_Sent__c = false;
            c.X40_Hour_Task_Created__c = false;
        }
    }
}