@isTest
private class AccountSummarizeAssetsQueueable_Test {

    @isTest
    static void testExpiredTriMechAssetsAreSummarized() {
        // Create test account
        Account testAccount = new Account(Name = 'TriMech Expired Test');
        insert testAccount;

        // Create active and expired TriMech assets
        List<Asset> testAssets = new List<Asset>{
            new Asset(
                AccountId = testAccount.Id,
                Name = 'Active TriMech',
                Quantity = 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware',
                RecordTypeId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('TriMech_Asset').getRecordTypeId(),
                Renewal_Expiration_date__c = Date.today().addDays(10)
            ),
            new Asset(
                AccountId = testAccount.Id,
                Name = 'Expired TriMech',
                Quantity = 1,
                Status = 'Expired',
                Asset_Type__c = 'Hardware',
                RecordTypeId = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('TriMech_Asset').getRecordTypeId(),
                Renewal_Expiration_date__c = Date.today().addDays(-10)
            )
        };
        insert testAssets;

        // Run the queueable
        Test.startTest();
        System.enqueueJob(new AccountSummarizeAssetsQueueable(new List<Id>{testAccount.Id}));
        Test.stopTest();

        // Query summaries
        List<Asset_Summary__c> summaries = [SELECT Id, Is_Expired__c, Asset_Count__c FROM Asset_Summary__c WHERE Account__c = :testAccount.Id];
        System.assertEquals(2, summaries.size(), 'Should summarize both active and expired TriMech assets');
        Boolean foundExpired = false, foundActive = false;
        for (Asset_Summary__c s : summaries) {
            if (s.Is_Expired__c) foundExpired = true;
            if (!s.Is_Expired__c) foundActive = true;
        }
        System.assert(foundExpired, 'Should have an expired summary');
        System.assert(foundActive, 'Should have an active summary');
    }
    // Removed accidental nested duplicate test class declaration
    
    @isTest
    static void testExecuteWithSingleAccount() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test assets for this account
        List<Asset> testAssets = new List<Asset>();
        for(Integer i = 0; i < 5; i++){
            Asset a = new Asset(
                AccountId = testAccount.Id,
                Name = 'Test Asset ' + i,
                Quantity = i + 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        insert testAssets;
        
        // Create and execute the queueable with single account
        List<Id> accountIds = new List<Id>{testAccount.Id};
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(accountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Verify that summaries were created
        Integer summaryCount = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c = :testAccount.Id];
        System.assertEquals(1, summaryCount, 'Should have created 1 summary for the account');
    }
    
    @isTest
    static void testExecuteWithMultipleAccounts() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 3; i++){
            testAccounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert testAccounts;
        
        // Create test assets for these accounts (simple approach)
        List<Asset> testAssets = new List<Asset>();
        // Add 5 assets to first account
        for(Integer i = 0; i < 5; i++){
            Asset a = new Asset(
                AccountId = testAccounts[0].Id,
                Name = 'Test Asset ' + i,
                Quantity = i + 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        // Add 5 assets to second account  
        for(Integer i = 0; i < 5; i++){
            Asset a = new Asset(
                AccountId = testAccounts[1].Id,
                Name = 'Test Asset ' + (i + 5),
                Quantity = i + 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        // Add 5 assets to third account
        for(Integer i = 0; i < 5; i++){
            Asset a = new Asset(
                AccountId = testAccounts[2].Id,
                Name = 'Test Asset ' + (i + 10),
                Quantity = i + 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        insert testAssets;
        
        // Create and execute the queueable with multiple accounts
        List<Id> accountIds = new List<Id>();
        for(Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(accountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Verify that summaries were created for all accounts
        Integer summaryCount = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c IN :accountIds];
        System.assertEquals(3, summaryCount, 'Should have created summaries for all 3 accounts');
    }
    
    @isTest
    static void testExecuteWithEmptyAccountList() {
        // Test with empty account list
        List<Id> emptyAccountIds = new List<Id>();
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(emptyAccountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Should not throw an exception
        System.assert(true, 'No exception should be thrown for empty account list');
    }
    
    @isTest
    static void testExecuteWithNullAccountList() {
        // Test with null account list
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(null);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Should not throw an exception
        System.assert(true, 'No exception should be thrown for null account list');
    }
    
    @isTest
    static void testExecuteWithAccountsWithoutAssets() {
        // Create test accounts with no assets
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 2; i++){
            testAccounts.add(new Account(Name = 'Test Account Without Assets ' + i));
        }
        insert testAccounts;
        
        // Create and execute the queueable
        List<Id> accountIds = new List<Id>();
        for(Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(accountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Verify that no summaries were created
        Integer summaryCount = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c IN :accountIds];
        System.assertEquals(0, summaryCount, 'Should have created 0 summaries for accounts without assets');
    }
    
    @isTest
    static void testExecuteWithLargeAccountBatch() {
        // Create test account
        Account testAccount = new Account(Name = 'Large Account Test');
        insert testAccount;
        
        // Create many assets for this account (to test batch processing)
        List<Asset> testAssets = new List<Asset>();
        for(Integer i = 0; i < 100; i++){
            Asset a = new Asset(
                AccountId = testAccount.Id,
                Name = 'Large Asset ' + i,
                Quantity = 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        insert testAssets;
        
        // Create and execute the queueable with single account (should handle large account)
        List<Id> accountIds = new List<Id>{testAccount.Id};
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(accountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Verify that summaries were created
        Integer summaryCount = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c = :testAccount.Id];
        System.assert(summaryCount > 0, 'Should have created summaries for large account');
    }
    
    @isTest
    static void testExecuteWithDisabledFlag() {
        // Temporarily disable the processing flag
        AccountSummarizeAssetsQueueable.disableProcessing = true;
        
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test assets
        List<Asset> testAssets = new List<Asset>();
        for(Integer i = 0; i < 3; i++){
            Asset a = new Asset(
                AccountId = testAccount.Id,
                Name = 'Test Asset ' + i,
                Quantity = 1,
                Status = 'Active',
                Asset_Type__c = 'Hardware'
            );
            testAssets.add(a);
        }
        insert testAssets;
        
        // Create and execute the queueable
        List<Id> accountIds = new List<Id>{testAccount.Id};
        AccountSummarizeAssetsQueueable queueable = new AccountSummarizeAssetsQueueable(accountIds);
        
        Test.startTest();
        queueable.execute(null);
        Test.stopTest();
        
        // Reset the flag
        AccountSummarizeAssetsQueueable.disableProcessing = false;
        
        // Verify that no summaries were created due to the disabled flag
        Integer summaryCount = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c = :testAccount.Id];
        System.assertEquals(0, summaryCount, 'Should have created 0 summaries when processing is disabled');
    }
}