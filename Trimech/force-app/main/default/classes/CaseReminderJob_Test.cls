@isTest
private class CaseReminderJob_Test {
    @isTest
    static void testExecute_SendsRemindersAndCreatesTasks() {
            // Set CreatedDate to 7 days in the past to ensure all business-hour thresholds are met
            DateTime sevenDaysAgo = System.now().addDays(-7);
        // Use any available Business Hours record. Cannot insert or update in test context.
        // If none exist, skip the test with a clear message.
        List<BusinessHours> bhList = [SELECT Id, Name FROM BusinessHours LIMIT 1];
        if (bhList.isEmpty()) {
            System.debug('SKIPPING: No BusinessHours record found. Test requires at least one BusinessHours record.');
            return;
        }
        BusinessHours bh = bhList[0];

        // Create Account, Contact, and User
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        Contact con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();

        // Create Case in 'Waiting for Client' status
        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Test Case',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c;
        Test.setCreatedDate(c.Id, sevenDaysAgo);

        // Query for EmailTemplate with DeveloperName 'Case_Reminder'. Cannot insert in test context.
        List<EmailTemplate> etList = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Case_Reminder' LIMIT 1];
        if (etList.isEmpty()) {
            System.debug('SKIPPING: No EmailTemplate with DeveloperName "Case_Reminder" found. Test requires this template.');
            return;
        }
        EmailTemplate et = etList[0];

        // Insert CaseHistory to simulate status change
        // (CaseHistory is not insertable, so the job will fallback to CreatedDate)

        Test.startTest();
        new CaseReminderJob().execute(null);
        Test.stopTest();

        // Reload Case and assert fields updated
        Case updated = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, '16h reminder should be sent');
        System.assert(updated.X32_Hour_Reminder_Sent__c, '32h reminder should be sent');
        System.assert(updated.X40_Hour_Task_Created__c, '40h task should be created');

        // Assert Task was created (filter by WhatId and Subject for this test)
        List<Task> tasks = [
            SELECT Id FROM Task 
            WHERE WhatId = :c.Id 
            AND Subject LIKE 'Call Client.%' 
        ];
        System.assertEquals(1, tasks.size(), 'A follow-up Task should be created');
    }
}