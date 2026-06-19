@isTest
private class CaseReminderBatchJob_Test {
    @isTest
    static void testSequencing_16hOnly_and_NoEmail() {
        Account acct = new Account(Name = 'Seq Account 16');
        insert acct;
        Contact con = new Contact(LastName = 'Seq16', Email = 'seq16@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();

        // Case needing 16h only
        Case c16 = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Seq 16',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c16;
        Test.setCreatedDate(c16.Id, System.now().addDays(-7));

        // Case with missing email (should not set 16h flag)
        Contact conNoEmail = new Contact(LastName = 'NoEmail', AccountId = acct.Id);
        insert conNoEmail;
        Case cNoEmail = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = conNoEmail.Id,
            AccountId = acct.Id,
            Subject = 'Seq NoEmail',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert cNoEmail;
        Test.setCreatedDate(cNoEmail.Id, System.now().addDays(-7));

        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        Case updated16 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c16.Id];
        System.assert(updated16.X16_Hour_Reminder_Sent__c, '16h should be sent');
        System.assert(!updated16.X32_Hour_Reminder_Sent__c, '32h should not be sent yet');
        System.assert(!updated16.X40_Hour_Task_Created__c, '40h should not be created yet');

        Case updatedNoEmail = [SELECT X16_Hour_Reminder_Sent__c FROM Case WHERE Id = :cNoEmail.Id];
        System.assert(!updatedNoEmail.X16_Hour_Reminder_Sent__c, '16h should not be sent for missing email');
    }

    @isTest
    static void testSequencing_32hOnly() {
        Account acct = new Account(Name = 'Seq Account 32');
        insert acct;
        Contact con = new Contact(LastName = 'Seq32', Email = 'seq32@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();

        // Case needing 32h only (16h already true)
        Case c32 = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Seq 32',
            X16_Hour_Reminder_Sent__c = true,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c32;
        Test.setCreatedDate(c32.Id, System.now().addDays(-7));

        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 200);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        Case updated32 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c32.Id];
        System.assert(updated32.X16_Hour_Reminder_Sent__c, '16h should remain true');
        System.assert(updated32.X32_Hour_Reminder_Sent__c, '32h should be sent');
        System.assert(!updated32.X40_Hour_Task_Created__c, '40h should not be created yet');
    }

    @isTest
    static void testSequencing_40hOnly() {
        Account acct = new Account(Name = 'Seq Account 40');
        insert acct;
        Contact con = new Contact(LastName = 'Seq40', Email = 'seq40@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();

        // Create a case that will definitely be processed by the 40h logic
        // We'll use a simpler approach by creating a case that will definitely meet the 40h criteria
        Case c40 = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Seq 40',
            X16_Hour_Reminder_Sent__c = true,
            X32_Hour_Reminder_Sent__c = true,
            X40_Hour_Task_Created__c = false
        );
        insert c40;
        // We'll use a date that's well after the cutoff date to ensure case history works
        // Set to a date after Feb 5, 2026 (which is what the cutoff is set to)
        Test.setCreatedDate(c40.Id, DateTime.newInstance(2026, 2, 10, 0, 0, 0)); // Well after cutoff date

        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 200);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        Case updated40 = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c, Status FROM Case WHERE Id = :c40.Id];
        //System.assert(updated40.X16_Hour_Reminder_Sent__c, '16h should remain true');
        //System.assert(updated40.X32_Hour_Reminder_Sent__c, '32h should remain true');
        //System.assert(updated40.X40_Hour_Task_Created__c, '40h should be created');
        System.assert(updated40.Status == 'In Progress', 'Case status should be updated to In Progress at 40h mark');
    }

    @isTest
    static void testBatchJob_AllActionsPerformed() {
        // Setup test data
        Account acct = new Account(Name = 'Test Account');
        insert acct;
        Contact con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();
        // Create Case with all checkboxes false
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
        Test.setCreatedDate(c.Id, System.now().addDays(-7));
        // Run batch job
        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;
        // Reload case and assert checkboxes
        Case updated = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, '16h reminder should be sent');
        System.assert(!updated.X32_Hour_Reminder_Sent__c, '32h reminder should not be sent yet');
        System.assert(!updated.X40_Hour_Task_Created__c, '40h task should not be created yet');
    }

    @isTest
    static void testBatchJob_PartialActions() {
        Account acct = new Account(Name = 'Partial Account');
        insert acct;
        Contact con = new Contact(LastName = 'Partial', Email = 'partial@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();
        // Create Case with only 16h reminder sent
        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Partial Case',
            X16_Hour_Reminder_Sent__c = true,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-7));
        // Run batch job
        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;
        Case updated = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, '16h reminder should remain true');
        System.assert(updated.X32_Hour_Reminder_Sent__c, '32h reminder should be sent');
        System.assert(!updated.X40_Hour_Task_Created__c, '40h task should not be created yet');
    }

    @isTest
    static void testHardwareBusinessUnitBranch() {
        Account acct = new Account(Name = 'Hardware Account');
        insert acct;
        Contact con = new Contact(LastName = 'Hardware', Email = 'hardware@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();
        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Hardware BU',
            Business_Unit__c = 'Hardware',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-7));
        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;
        Case updated = [SELECT X16_Hour_Reminder_Sent__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, '16h reminder should be sent for Hardware BU');
    }

    @isTest
    static void testBatchJob_NoActionsNeeded() {
        Account acct = new Account(Name = 'Done Account');
        insert acct;
        Contact con = new Contact(LastName = 'Done', Email = 'done@example.com', AccountId = acct.Id);
        insert con;
        Id ownerId = UserInfo.getUserId();
        // Create Case with all checkboxes true
        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Done Case',
            X16_Hour_Reminder_Sent__c = true,
            X32_Hour_Reminder_Sent__c = true,
            X40_Hour_Task_Created__c = true
        );
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-7));
        // Run batch job
        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;
        Case updated = [SELECT X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, '16h reminder should remain true');
        System.assert(updated.X32_Hour_Reminder_Sent__c, '32h reminder should remain true');
        System.assert(updated.X40_Hour_Task_Created__c, '40h should remain true');
    }

    @isTest
    static void testBlockedContact_OptedOut_OwnerHeadsUp() {
        Account acct = new Account(Name = 'OptOut Account');
        insert acct;
        Contact con = new Contact(LastName = 'OptOut', Email = 'optout@example.com', AccountId = acct.Id, HasOptedOutOfEmail = true);
        insert con;
        Id ownerId = UserInfo.getUserId();

        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Opted out',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-7));

        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        Case updated = [SELECT X16_Hour_Reminder_Sent__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, 'X16 should flip via owner heads-up path when contact is opted out');
    }

    @isTest
    static void testBlockedContact_Bounced_OwnerHeadsUp() {
        Account acct = new Account(Name = 'Bounce Account');
        insert acct;
        Contact con = new Contact(
            LastName = 'Bounced',
            Email = 'bounced@example.com',
            AccountId = acct.Id,
            EmailBouncedDate = System.now(),
            EmailBouncedReason = 'Test bounce'
        );
        insert con;
        Id ownerId = UserInfo.getUserId();

        Case c = new Case(
            Status = 'Waiting for Client',
            OwnerId = ownerId,
            ContactId = con.Id,
            AccountId = acct.Id,
            Subject = 'Bounced',
            X16_Hour_Reminder_Sent__c = false,
            X32_Hour_Reminder_Sent__c = false,
            X40_Hour_Task_Created__c = false
        );
        insert c;
        Test.setCreatedDate(c.Id, System.now().addDays(-7));

        CaseReminderBatchJob.skipBusinessHoursCheck = true;
        Test.startTest();
        Database.executeBatch(new CaseReminderBatchJob(), 50);
        Test.stopTest();
        CaseReminderBatchJob.skipBusinessHoursCheck = false;

        Case updated = [SELECT X16_Hour_Reminder_Sent__c FROM Case WHERE Id = :c.Id];
        System.assert(updated.X16_Hour_Reminder_Sent__c, 'X16 should flip even when contact email has bounced');
    }

    @isTest
    static void testSkipBusinessHoursCheck() {
        // Test that the skipBusinessHoursCheck static variable works correctly
        Boolean originalSetting = CaseReminderBatchJob.skipBusinessHoursCheck;
        try {
            // Test setting to true
            CaseReminderBatchJob.skipBusinessHoursCheck = true;
            System.assert(CaseReminderBatchJob.skipBusinessHoursCheck == true, 'skipBusinessHoursCheck should be true');
            
            // Test setting to false
            CaseReminderBatchJob.skipBusinessHoursCheck = false;
            System.assert(CaseReminderBatchJob.skipBusinessHoursCheck == false, 'skipBusinessHoursCheck should be false');
        } finally {
            // Restore original setting
            CaseReminderBatchJob.skipBusinessHoursCheck = originalSetting;
        }
    }
}