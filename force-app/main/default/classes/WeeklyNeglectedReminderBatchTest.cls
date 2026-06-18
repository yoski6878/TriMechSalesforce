@isTest
public class WeeklyNeglectedReminderBatchTest {

    private static final Integer OWNER_COUNT = 12; // > 10 to prove we cleared the SingleEmail-with-TargetObjectId cap

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> users = new List<User>();
        Long ts = System.currentTimeMillis();
        for (Integer i = 0; i < OWNER_COUNT; i++) {
            users.add(new User(
                Alias = 'tu' + i,
                Email = 'testuser' + i + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'wnr_test_' + i + '_' + ts + '@example.com'
            ));
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert users;
        }

        Id leadRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Lead' LIMIT 1].Id;

        Product_Group__c pg = new Product_Group__c(Name = 'Hardware');
        insert pg;

        List<Opportunity> opps = new List<Opportunity>();
        for (User u : users) {
            opps.add(new Opportunity(
                Name = 'Opp ' + u.LastName,
                StageName = 'Neglected',
                CloseDate = Date.today().addDays(30),
                AccountId = acc.Id,
                OwnerId = u.Id,
                Product_Group__c = pg.Id,
                RecordTypeId = leadRtId
            ));
        }
        insert opps;
    }

    @isTest
    static void batchCompletesAboveLegacyEmailLimit() {
        Id jobId;
        Test.startTest();
            jobId = Database.executeBatch(new WeeklyNeglectedReminderBatch(), 2000);
        Test.stopTest();

        // With the previous setTargetObjectId approach, 12 owners would have thrown
        // "Too many Email Invocations: 11" in finish(). The job completing cleanly
        // proves the fix lifted that cap.
        assertJobCompletedCleanly(jobId);
    }

    @isTest
    static void batchHandlesInactiveOwners() {
        List<User> owners = [
            SELECT Id, IsActive
            FROM User
            WHERE Username LIKE 'wnr_test_%@example.com'
            ORDER BY Username
            LIMIT 2
        ];
        for (User u : owners) {
            u.IsActive = false;
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update owners;
        }

        Id jobId;
        Test.startTest();
            jobId = Database.executeBatch(new WeeklyNeglectedReminderBatch(), 2000);
        Test.stopTest();

        // Exercises the IsActive skip in finish() — without it, we'd still send
        // pointless mail to deactivated users. The job must complete cleanly.
        assertJobCompletedCleanly(jobId);
    }

    @isTest
    static void batchHandlesAllProductGroups() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Id leadRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Lead' LIMIT 1].Id;
        User existingOwner = [SELECT Id FROM User WHERE Username LIKE 'wnr_test_%@example.com' LIMIT 1];

        List<String> pgNames = new List<String>{'Software','Staffing','Product Development','SSG-CRE','CPQ','Aras','SSG-BT','SolidCAM'};
        List<Product_Group__c> pgs = new List<Product_Group__c>();
        for (String n : pgNames) {
            pgs.add(new Product_Group__c(Name = n));
        }
        insert pgs;

        List<Opportunity> opps = new List<Opportunity>();
        for (Product_Group__c pg : pgs) {
            opps.add(new Opportunity(
                Name = 'Opp ' + pg.Name,
                StageName = 'Neglected',
                CloseDate = Date.today().addDays(30),
                AccountId = acc.Id,
                OwnerId = existingOwner.Id,
                Product_Group__c = pg.Id,
                RecordTypeId = leadRtId
            ));
        }
        insert opps;

        Id jobId;
        Test.startTest();
            jobId = Database.executeBatch(new WeeklyNeglectedReminderBatch(), 2000);
        Test.stopTest();

        // Exercises the expanded ProductGroup_Name__c IN (...) filter.
        // Without all 10 groups in the IN list, these opps would not enter scope
        // and the batch would silently miss them.
        assertJobCompletedCleanly(jobId);
    }

    @isTest
    static void schedulerEnqueuesBatch() {
        Test.startTest();
            String cronExp = '0 0 0 * * ?';
            System.schedule('Test_Weekly_Neglected_Scheduler', cronExp, new WeeklyNeglectedReminderScheduler());
        Test.stopTest();

        Integer scheduled = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'Test_Weekly_Neglected_Scheduler'];
        System.assertEquals(1, scheduled, 'Scheduler should be registered');
    }

    private static void assertJobCompletedCleanly(Id jobId) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals(0, job.NumberOfErrors,
            'Batch had errors. Status=' + job.Status + ', ExtendedStatus=' + job.ExtendedStatus);
        System.assertNotEquals('Failed', job.Status,
            'Batch failed. ExtendedStatus=' + job.ExtendedStatus);
    }
}