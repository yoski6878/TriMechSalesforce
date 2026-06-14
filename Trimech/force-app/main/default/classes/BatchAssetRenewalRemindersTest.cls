@isTest
private class BatchAssetRenewalRemindersTest {

    @isTest
    static void testBatchExecution() {
        User salesRep = [SELECT Id FROM User WHERE IsActive = TRUE AND LastName = 'Harpalani' LIMIT 1];

        Account acct1 = new Account(Name = 'Test Account 1', Dedicated_Sales_Rep_Software__c = salesRep.Id, Dedicated_Sales_Rep_Hardware__c = salesRep.Id);
        insert acct1;

        Asset asset1 = new Asset(Name = 'Asset PDM 1', Status = 'Active', Quantity = 10, AccountId = acct1.Id, UsageEndDate = system.Today().addDays(91), RecordTypeId = '0126g000001OsLfAAK');
        Asset asset2 = new Asset(Name = 'Asset CAD 1', Status = 'Active', Quantity = 1, AccountId = acct1.Id, UsageEndDate = system.Today().addDays(10), RecordTypeId = '0126g000001OsLfAAK');
        Asset asset3 = new Asset(Name = 'Asset Scanner 1', Status = 'Active', Quantity = 6, Asset_Type__c='Scanner', AccountId = acct1.Id, UsageEndDate = system.Today().addDays(10), RecordTypeId = '0126g000001OsLkAAK');
        List<Asset> assetList1 = new List<Asset>{asset1,asset2, asset3};
        insert assetList1;

        Account acct2 = new Account(Name = 'Test Account 1', Dedicated_Sales_Rep_Software__c = salesRep.Id, Dedicated_Sales_Rep_Hardware__c = salesRep.Id);
        insert acct2;

        List<Asset> assetList2 = new List<Asset>();
        for(Integer i=1; i<=10; i++){
            Date endDate = system.Today().addDays(i);
            assetList2.add(new Asset(Name = 'Asset PDM ' + i, Status = 'Active', Quantity = 10, AccountId = acct2.Id, UsageEndDate = endDate, RecordTypeId = '0126g000001OsLfAAK'));
            assetList2.add(new Asset(Name = 'Asset Scanner ' + i, Status = 'Active', Quantity = 7, Asset_Type__c='Scanner', AccountId = acct2.Id, UsageEndDate = endDate, RecordTypeId = '0126g000001OsLkAAK'));
        }
        insert assetList2;
        
        Test.startTest();
        BatchAssetRenewalReminders batch = new BatchAssetRenewalReminders();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Task> tasks1 = [SELECT Id, Subject FROM Task WHERE WhatId = :acct1.Id];
        System.debug('Size of tasks1: ' + tasks1.size());
        System.assert(tasks1.isEmpty(), 'No Tasks should be created for Account');

        List<Task> tasks2 = [SELECT Id, Subject FROM Task WHERE WhatId = :acct2.Id];
        System.debug('Size of tasks2: ' + tasks2.size());
        System.assert(tasks2.size() > 0, 'Task should be created for Account');

    }
}