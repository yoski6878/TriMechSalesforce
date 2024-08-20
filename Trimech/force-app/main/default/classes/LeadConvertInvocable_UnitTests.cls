@isTest
public class LeadConvertInvocable_UnitTests {
    @TestSetup
    public static void makeData(){
        Account a = new Account(Name = 'Test Company', ShippingPostalCode = '12345');
        Account b = new Account(Name = 'Test Company 2', ShippingPostalCode = '12346');
        insert new List<Account> {a,b};
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Neglected', CloseDate = Date.today(), AccountId = a.Id, Lead_Product_Category_on_Opp__c = 'DraftSight', Lead_Product_of_Interest_on_Opp__c = 'DraftSight Enterprise');
        insert opp;

        Product_Group__c pg = new Product_Group__c(Name='Software');
        insert pg;

        Pardot_Lead_ASsignment__c PLA = new Pardot_Lead_Assignment__c(Name='DraftSight', PLA_Product_Group__c=pg.id, Assignment_Group__c = 'Software', Sales_Rep_to_Assign__c = 'Software', Solution_Type__c='Standard');
        insert PLA;
    }

    @isTest
    public static void it_should_convert_one_matching_lead() {
        Lead l = new Lead(
            Company = 'Test Company',
            Email = 'test@example.com',
            LastName = 'Test1',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus',
            Campaign_Type__c = 'MQL',
            Status='Unqualified'
        );
        insert l;
        system.debug('LeadConvertInvocable_UnitTests: ' + l);

        System.assert(l.id != null);

        Lead l2 = new Lead(
            Company = 'Test Company',
            Email = 'test2@example.com',
            LastName = 'Test2',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus',
            Campaign_Type__c = 'UQL',
            Status = 'Unqualified'
        );
        insert l2;
        system.debug('LeadConvertInvocable_UnitTests: ' + l2);
        String fakeFlowId = 'abcdefg1234';

        l.Status='New';
        l2.Status='New';
        update new List<Lead>{l, l2};

        List<Lead> newLeads = new List<Lead>();
        newLeads.add(l);
        newLeads.add(l2);

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.leadList = newLeads;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>();
        requests.add(req);
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 1 Response should be returned
        System.assertEquals(1, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // Flow ID should match request
        System.assertEquals(fakeFlowId, resp.flowInterviewId);

        // LeadConvertBatch job should be created
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        List<Lead> convertedLeads = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id = :l.Id OR id = :l2.id
        ];

        // Lead shuold be converted
        System.assertEquals(2, convertedLeads.size());
        System.assertEquals(true, convertedLeads[0].IsConverted);
        System.assertEquals(true, convertedLeads[1].IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should only be 1 Opp still
        System.assertEquals(1, opps.size());
    }

    /*@isTest
    public static void it_should_convert_one_unmatched_lead() {
         Lead l = new Lead(
             Company = 'Test Non Match',
             Email = 'test@example.com',
             LastName = 'Test',
             PostalCode = '12345',
             Lead_Product_Category__c = 'DraftSight',
             Lead_Product_of_Interest__c = 'DraftSight Enterprise',
             Status = 'Working'
        );

        insert l;
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.lead = l;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req};
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        System.assertEquals(fakeFlowId, resp.flowInterviewId);
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        Lead convertedLead = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id = :l.Id
        ];

        System.assertEquals(true, convertedLead.IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should be 2 Opps
        System.assertEquals(2, opps.size());
    }

    @isTest
    public static void it_should_convert_two_matching_leads() {
        Lead l1 = new Lead(
            Company = 'Test Company',
            Email = 'test1@example.com',
            LastName = 'Test1',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus'
        );

        Lead l2 = new Lead(
            Company = 'Test Company',
            Email = 'test2@example.com',
            LastName = 'Test2',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus'
        );

        List<Lead> leads = new List<Lead>{l1, l2};
        insert leads;
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req1 = new LeadConvertInvocable.InvocationRequest();
        req1.batchSize = 10;
        req1.lead = l1;
        req1.flowInterviewId = fakeFlowId;

        LeadConvertInvocable.InvocationRequest req2 = new LeadConvertInvocable.InvocationRequest();
        req2.batchSize = 10;
        req2.lead = l2;
        req2.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req1, req2};
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 2 Response should be returned
        System.assertEquals(2, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // Flow ID should match request
        System.assertEquals(fakeFlowId, resp.flowInterviewId);

        // LeadConvertBatch job should be created
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        List<Lead> convertedLeads = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id IN :leads
        ];

        System.assertEquals(2, convertedLeads.size());

        Lead convertedLead = convertedLeads[0];

        // Lead shuold be converted
        System.assertEquals(true, convertedLead.IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should only be 1 Opp still
        System.assertEquals(1, opps.size());
    }

    @isTest
    public static void it_should_return_an_error_with_no_lead(){ 
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.lead = null;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req};
    
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 1 Response should be returned
        System.assertEquals(1, responses.size());

        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // No lead should be batched and error message should have contents
        System.assertEquals(false, resp.leadBatched);
        System.assertNotEquals(null, resp.errorMessage);

    }*/

    // @isTest
    // public static void testMatchingLead() {
    //     Lead l = new Lead(Company = 'Test Company', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    // }

    // @isTest
    // public static void testMatchingLeadTwo() {
    //     Lead l = new Lead(Company = 'Test Company 2', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    // }

    // @isTest
    // public static void testUQL() {
    //     Lead l = new Lead(Company = 'Test UQL', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise', Campaign_Type__c = 'UQL', Status = 'Working');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(0, opps.size());
    // }

    // @isTest
    // public static void testNonMatchingLead() {
    //     Lead l = new Lead(Company = 'Test Non Match', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise', Status = 'Working');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    //     System.assertEquals(Date.today().addDays(30), opps[0].CloseDate);
    // }

}