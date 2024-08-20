@isTest
private class Asset_Trigger_UnitTests {
	
    @isTest
	private static void testCreateAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a4 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 1, Status = 'Active', Item__c = 'Test FDM Test', RecordTypeId='0126g000001OsLkAAK', Printer_Technology__c='FDM');
        
        Test.startTest();
        insert new Asset[]{a1,a2,a3,a4};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size(), '');
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Group__c = 'FDM'].size(), '');


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
	private static void testUpdateAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a4 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test FDM Test', RecordTypeId='0126g000001OsLkAAK', Printer_Technology__c='FDM');

        insert new Asset[]{a1,a2,a3,a4};
            
        //System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size());


        a1.Quantity = 1;
        a2.Quantity = 1;
        a3.Quantity = 2;
        a4.Status = 'Sold';
        
        Test.startTest();
        update new Asset[]{a1,a2,a3,a4};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 2].size(), '');
        System.assertEquals(0,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Group__c = 'FDM'].size(), '');
        
        /*delete new Asset[]{a1,a3};
            
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 1].size());   
    */
    }

    @isTest
	private static void testDeleteAssetSummaries(){
		
        Account acc = new Account(Name = 'Eustace Consulting');
        insert acc;
        
        Asset a1 = new Asset(AccountId = acc.Id, Name = 'Test Asset 1', Quantity = 2, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a2 = new Asset(AccountId = acc.Id, Name = 'Test Asset 2', Quantity = 3, Status = 'Active', Item__c = 'Test PDM Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a3 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test CAD Test', RecordTypeId='0126g000001OsLfAAK');
        Asset a4 = new Asset(AccountId = acc.Id, Name = 'Test Asset 3', Quantity = 5, Status = 'Active', Item__c = 'Test FDM Test', RecordTypeId='0126g000001OsLkAAK', Printer_Technology__c='FDM');
        
        insert new Asset[]{a1,a2,a3,a4};
            
        //System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 5].size());


        /*a1.Quantity = 1;
        a2.Quantity = 1;
        a3.Quantity = 2;
        
        Test.startTest();
        update new Asset[]{a1,a2,a3};
        Test.stopTest();
            
        System.assertEquals(2,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id AND Asset_Count__c = 2].size());*/
        
        Test.startTest();
        delete new Asset[]{a1,a3,a4};
        Test.stopTest();
            
        System.assertEquals(1,[SELECT Id FROM Asset_Summary__c WHERE Account__c = :acc.Id].size(), '');   
    
    }
}