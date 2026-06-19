@isTest
private class Asset_Trigger_Test {
    @isTest
    static void testAfterInsert() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account', High_Asset_Inventory__c = false);
        insert acc;
        
        // Create test Asset
        Asset asset = new Asset(Name = 'Test Asset', AccountId = acc.Id);
        insert asset;
        
        // Add assertions as needed (e.g., check for enqueued jobs or summary records)
        System.assertNotEquals(null, asset.Id);
    }

    @isTest
    static void testAfterUpdate() {
        Account acc = new Account(Name = 'Test Account', High_Asset_Inventory__c = false);
        insert acc;
        Asset asset = new Asset(Name = 'Test Asset', AccountId = acc.Id);
        insert asset;
        asset.Description = 'Updated Description';
        update asset;
        System.assertEquals('Updated Description', [SELECT Description FROM Asset WHERE Id = :asset.Id].Description);
    }

    @isTest
    static void testAfterDelete() {
        Account acc = new Account(Name = 'Test Account', High_Asset_Inventory__c = false);
        insert acc;
        Asset asset = new Asset(Name = 'Test Asset', AccountId = acc.Id);
        insert asset;
        delete asset;
        System.assertEquals(0, [SELECT COUNT() FROM Asset WHERE Id = :asset.Id]);
    }

    @isTest
    static void testHighVolumeAccount() {
        Account acc = new Account(Name = 'High Volume Account', High_Asset_Inventory__c = true);
        insert acc;
        Asset asset = new Asset(Name = 'Test Asset', AccountId = acc.Id);
        insert asset;
        System.assertNotEquals(null, asset.Id);
    }
}