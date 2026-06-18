/**
* @File Name : BatchToNotifyForInactiveOLITest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 28, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 28, 2025 |   | Initial Version
**/

@isTest
private class BatchToNotifyForInactiveOLITest {
	
	@isTest
    static void testBatchExecution() {
        Test.startTest();
        
        User testUser = [SELECT Id, Email FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'In Progress',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id,
            OwnerId = testUser.Id
        );
        insert testOpp;
        
        Product2 testProduct = new Product2(Name = 'Test Product', IsActive = false);
        insert testProduct;
        
        PricebookEntry testPBE = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = testProduct.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert testPBE;
        
        OpportunityLineItem testOLI = new OpportunityLineItem(
            OpportunityId = testOpp.Id,
            PricebookEntryId = testPBE.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert testOLI;
        
        // Execute batch
        BatchToNotifyForInactiveOLI batch = new BatchToNotifyForInactiveOLI();
        Database.executeBatch(batch);
        
        Test.stopTest();
	}
}