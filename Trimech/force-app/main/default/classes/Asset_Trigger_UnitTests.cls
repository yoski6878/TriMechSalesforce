@isTest
private class Asset_Trigger_UnitTests {
	
    @isTest
	private static void TestCreateAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test');
        
        Test.startTest();
        insert new Asset[]{a1,a2,a3};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size());


        /*a1.Quantity = 1;
        a2.Quantity = 1;
        a3.Quantity = 2;
        update new Asset[]{a1,a2,a3};
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 2].size());
        
        delete new Asset[]{a1,a3};
            
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 1].size());   
    */
    }

    @isTest
	private static void TestUpdateAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test');
        
        insert new Asset[]{a1,a2,a3};
            
        //System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size());


        a1.Quantity = 1;
        a2.Quantity = 1;
        a3.Quantity = 2;
        
        Test.startTest();
        update new Asset[]{a1,a2,a3};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 2].size());
        
        /*delete new Asset[]{a1,a3};
            
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 1].size());   
    */
    }

    @isTest
	private static void TestDeleteAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test');
        
        insert new Asset[]{a1,a2,a3};
            
        //System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size());


        /*a1.Quantity = 1;
        a2.Quantity = 1;
        a3.Quantity = 2;
        
        Test.startTest();
        update new Asset[]{a1,a2,a3};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 2].size());*/
        
        Test.startTest();
        delete new Asset[]{a1,a3};
        Test.stopTest();
            
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id].size());   
    
    }
}