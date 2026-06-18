@isTest
private class CaseReminderBatchJob_Test2 {
    @isTest
    static void testAllMilestonesAndEdgeCases() {
        // Setup test data
        Account acct = new Account(Name = 'Full Coverage Account');
        insert acct;
        Contact con16 = new Contact(LastName = 'C16', Email = 'c16@example.com', AccountId = acct.Id);
        insert con16;
        Contact con32 = new Contact(LastName = 'C32', Email = 'c32@example.com', AccountId = acct.Id);
        insert con32;
        Contact con40 = new Contact(LastName = 'C40', Email = 'c40@example.com', AccountId = acct.Id);
        insert con40;
        Contact conNoEmail = new Contact(LastName = 'NoEmail', AccountId = acct.Id);
        insert conNoEmail;
        Id ownerId = UserInfo.getUserId();

        // 16h eligible
        Case c16 = new Case(Status = 'Waiting for Client', OwnerId = ownerId, ContactId = con16.Id, AccountId = acct.Id, Subject = '16h', X16_Hour_Reminder_Sent__c = false, X32_Hour_Reminder_Sent__c = false, X40_Hour_Task_Created__c = false);
        insert c16;
        Test.setCreatedDate(c16.Id, System.now().addDays(-7));
        // 32h eligible
        Case c32 = new Case(Status = 'Waiting for Client', OwnerId = ownerId, ContactId = con32.Id, AccountId = acct.Id, Subject = '32h', X16_Hour_Reminder_Sent__c = true, X32_Hour_Reminder_Sent__c = false, X40_Hour_Task_Created__c = false);
        insert c32;
        Test.setCreatedDate(c32.Id, System.now().addDays(-7));
        // 40h eligible
        Case c40 = new Case(Status = 'Waiting for Client', OwnerId = ownerId, ContactId = con40.Id, AccountId = acct.Id, Subject = '40h', X16_Hour_Reminder_Sent__c = true, X32_Hour_Reminder_Sent__c = true, X40_Hour_Task_Created__c = false);
        insert c40;
        Test.setCreatedDate(c40.Id, System.now().addDays(-7));
        // No email
        Case cNoEmail = new Case(Status = 'Waiting for Client', OwnerId = ownerId, ContactId = conNoEmail.Id, AccountId = acct.Id, Subject = 'NoEmail', X16_Hour_Reminder_Sent__c = false, X32_Hour_Reminder_Sent__c = false, X40_Hour_Task_Created__c = false);
        insert cNoEmail;
        Test.setCreatedDate(cNoEmail.Id, System.now().addDays(-7));
        // Already completed
        Case cDone = new Case(Status = 'Waiting for Client', OwnerId = ownerId, ContactId = con16.Id, AccountId = acct.Id, Subject = 'Done', X16_Hour_Reminder_Sent__c = true, X32_Hour_Reminder_Sent__c = true, X40_Hour_Task_Created__c = true);
        insert cDone;
        Test.setCreatedDate(cDone.Id, System.now().addDays(-7));

        // Run batch with business hours check bypassed
        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        // Assert 16h
        Case updated16 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c16.Id];
        System.assert(updated16.X16_Hour_Reminder_Sent__c, '16h should be sent');
        System.assert(!updated16.X32_Hour_Reminder_Sent__c, '32h should not be sent yet');
        System.assert(!updated16.X40_Hour_Task_Created__c, '40h should not be created yet');
        // Assert 32h
        Case updated32 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c32.Id];
        System.assert(updated32.X16_Hour_Reminder_Sent__c, '16h should remain true');
        System.assert(updated32.X32_Hour_Reminder_Sent__c, '32h should be sent');
        System.assert(!updated32.X40_Hour_Task_Created__c, '40h should not be created yet');
        // Assert 40h
        Case updated40 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c40.Id];
        System.assert(updated40.X16_Hour_Reminder_Sent__c, '16h should remain true');
        System.assert(updated40.X32_Hour_Reminder_Sent__c, '32h should remain true');
        System.assert(updated40.X40_Hour_Task_Created__c, '40h should be created');
        // Assert no email
        Case updatedNoEmail = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :cNoEmail.Id];
        System.assert(!updatedNoEmail.X16_Hour_Reminder_Sent__c, '16h should not be sent for missing email');
        System.assert(!updatedNoEmail.X32_Hour_Reminder_Sent__c, '32h should not be sent for missing email');
        System.assert(!updatedNoEmail.X40_Hour_Task_Created__c, '40h should not be created for missing email');
        // Assert already completed
        Case updatedDone = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :cDone.Id];
        System.assert(updatedDone.X16_Hour_Reminder_Sent__c, '16h should remain true (done)');
        System.assert(updatedDone.X32_Hour_Reminder_Sent__c, '32h should remain true (done)');
        System.assert(updatedDone.X40_Hour_Task_Created__c, '40h should remain true (done)');
    }
}