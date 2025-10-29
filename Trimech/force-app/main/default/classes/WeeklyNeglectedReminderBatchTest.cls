@isTest
public class WeeklyNeglectedReminderBatchTest {
    
    @testSetup
    static void setupData() {
        // Create test account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create test user (needed as Opportunity Owner)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email='testuser@example.com',
            EmailEncodingKey='UTF-8',
            LastName='Testing',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId=p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            Username='testuser' + System.currentTimeMillis() + '@example.com'
        );
        insert u;
        
        // Create Opportunity record type "Lead" if it exists in org
        Id leadRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Lead' LIMIT 1].Id;
        
        Product_Group__c pg = new product_Group__c();
        pg.Name = 'Hardware';
        insert pg;
        
        // Create opportunities
        Opportunity opp1 = new Opportunity(
            Name = 'Opp 1',
            StageName = 'Neglected',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            OwnerId = u.Id,
            Product_Group__c = pg.Id,
            RecordTypeId = leadRtId
        );
        Opportunity opp2 = new Opportunity(
            Name = 'Opp 2',
            StageName = 'Neglected',
            CloseDate = Date.today().addDays(40),
            AccountId = acc.Id,
            OwnerId = u.Id,
            Product_Group__c = pg.Id,
            RecordTypeId = leadRtId
        );
        insert new List<Opportunity>{opp1, opp2};
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
            String cronExp = '0 0 0 * * ?';
           String jobId = System.schedule('Test_Opportunity_Reassignment_Scheduler', cronExp, new WeeklyNeglectedReminderScheduler());
        Test.stopTest();
    }
}