@isTest
private class CaseReminderResetTrigger_Test {
    @isTest
    static void testResetsReminderFieldsOnStatusChange() {
        // Create Account, Contact, and User
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        Contact con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();

        // Create Case in 'Waiting for Client' with all flags true
        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Test Case',
            X16_Hour_Reminder_Sent__c = true,
            X32_Hour_Reminder_Sent__c = true,
            X40_Hour_Task_Created__c = true
        );
        insert c;

        // Change status to something else
        c.Status = 'Working';
        update c;

        // Reload and assert fields reset
        Case updated = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(false, updated.X16_Hour_Reminder_Sent__c, '16h flag should be reset');
        System.assertEquals(false, updated.X32_Hour_Reminder_Sent__c, '32h flag should be reset');
        System.assertEquals(false, updated.X40_Hour_Task_Created__c, '40h flag should be reset');
    }
}