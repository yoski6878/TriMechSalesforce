@isTest
private class TaskTrigger_UnitTests {

    @isTest
    private static void testCreateLeadAssignmentProcessRecord(){
        
        Account a = new Account(Name = 'Eustace Consulting');
        insert a;
        
        Contact c = new Contact(LastName = 'Reff', AccountId = a.Id);
        insert c;
        
        Campaign camp = new Campaign(Name = 'Test Campaign', IsActive = true, Lead_Status__c = 'MQL');
        insert camp;
        
        Product_Group__c group1 = new Product_Group__c(Name = 'Group A');
        Product_Group__c group2 = new Product_Group__c(Name = 'Group B');
        insert new Product_Group__c[]{group1,group2};
        
        Product2 p1 = new Product2(Name = 'Product A', Product_Group__c = group1.Id);
        Product2 p2 = new Product2(Name = 'Product B', Product_Group__c = group1.Id);
        Product2 p3 = new Product2(Name = 'Product C', Product_Group__c = group2.Id);
        insert new Product2[]{p1,p2,p3};
            
        Campaign_Product__c cp1 = new Campaign_Product__c(Campaign__c = camp.Id, Product__c = p1.Id);
        Campaign_Product__c cp2 = new Campaign_Product__c(Campaign__c = camp.Id, Product__c = p2.Id);
        Campaign_Product__c cp3 = new Campaign_Product__c(Campaign__c = camp.Id, Product__c = p3.Id);
        insert new Campaign_Product__c[]{cp1,cp2,cp3};
        
        String taskDesc = 'sfCampaignId: ' + camp.Id + '\n' + 'Vendor Name: TriMech' + '\n' + 'Source Program: CampaignNameTest' + '\n' + 'Source Type: Lead Import' + '\n';
        /*
        taskDesc += 'utm_source: testSource\n';
        taskDesc += 'utm_campaign: testCamp\n';
        taskDesc += 'utm_medium: testMedium\n';
        taskDesc += 'utm_term: testTerm\n';
        taskDesc += 'utm_content: testContent';
        */
            
        Task t = new Task(Subject = 'Call', Type = 'Form Submission', ActivityDate = System.today(), WhoId = c.Id, WhatId = a.Id, Description = taskDesc);
        Test.startTest(); 
        insert t;
        Test.stopTest();
        
        //because we're using a chained Queueable class to insert LAP records, we can only assert the first link in the chain (can't have chained queuables in a unit test)
        //System.assertEquals(2,[SELECT Id FROM Lead_Assignment_Process__c WHERE Task_ID__c = :t.Id].size());
        //System.assertEquals(2,[SELECT Id FROM Lead_Assignment_Process__c WHERE Product_Interest__c != null].size());
        System.assertEquals(2,[SELECT Id FROM Lead_Assignment_Process__c WHERE Task_ID__c = :t.Id].size());
        System.assertEquals(2,[SELECT Id FROM Lead_Assignment_Process__c WHERE Product_Interest__c != null].size());
    }
}