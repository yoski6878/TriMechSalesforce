@isTest
public class AccountAssetSummaryServiceTest {
    @testSetup
    static void setup() {
        // Create multiple Accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;

        // Create Product2 records
        Product2 prod1 = new Product2(Name = 'Prod1', Class__c = 'CAD', Technology__c = 'Software');
        Product2 prod2 = new Product2(Name = 'Prod2', Class__c = 'CAM', Technology__c = 'Scanner');
        insert new List<Product2>{prod1, prod2};

        // Create RecordType for TriMech_Asset
        RecordType triMechRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Asset' AND DeveloperName = 'TriMech_Asset' LIMIT 1];

        // Create Assets with various combinations
        List<Asset> assets = new List<Asset>{
            // Valid Software Asset
            new Asset(Name = 'Software Asset', AccountId = accounts[0].Id, Quantity = 2, Asset_Type__c = 'Software', Product2Id = prod1.Id),
            // Valid Hardware Asset
            new Asset(Name = 'Hardware Asset', AccountId = accounts[1].Id, Quantity = 1, Asset_Type__c = 'Hardware', Product2Id = prod2.Id),
            // TriMech Asset with Active status
            new Asset(Name = 'TriMech Asset', AccountId = accounts[2].Id, Quantity = 3, Asset_Type__c = 'Hardware', Product2Id = prod1.Id, RecordTypeId = triMechRT.Id, Status = 'Active'),
            // TriMech Asset with Inactive status (should now be included)
            new Asset(Name = 'TriMech Asset Inactive', AccountId = accounts[2].Id, Quantity = 1, Asset_Type__c = 'Hardware', Product2Id = prod2.Id, RecordTypeId = triMechRT.Id, Status = 'Inactive'),
            // TriMech Asset with Expired status
            new Asset(Name = 'TriMech Asset Expired', AccountId = accounts[2].Id, Quantity = 1, Asset_Type__c = 'Hardware', Product2Id = prod2.Id, RecordTypeId = triMechRT.Id, Status = 'Expired', Renewal_Expiration_date__c = Date.today().addDays(-5)),
            // Asset with null Quantity (should be skipped)
            new Asset(Name = 'Null Quantity Asset', AccountId = accounts[0].Id, Asset_Type__c = 'Software', Product2Id = prod1.Id),
            // Asset with null Asset_Type__c (should be skipped)
            new Asset(Name = 'Null Type Asset', AccountId = accounts[1].Id, Quantity = 1, Product2Id = prod2.Id)
        };
        insert assets;
    }

    @isTest
    static void testRecalculate() {
        List<Account> accounts = [SELECT Id FROM Account];
        Set<Id> acctIds = new Set<Id>();
        for (Account acc : accounts) {
            acctIds.add(acc.Id);
        }
        Test.startTest();
        AccountAssetSummaryService.recalculate(acctIds);
        Test.stopTest();

        // Assert Asset_Summary__c records were created for valid assets
        List<Asset_Summary__c> summaries = [SELECT Id, Account__c, Asset_Type__c, Asset_Count__c FROM Asset_Summary__c WHERE Account__c IN :acctIds];
        System.assert(summaries.size() > 0, 'Asset_Summary__c records should be created');

        // Assert all TriMech assets (including Inactive and Expired) are summarized
        Boolean foundActive = false, foundInactive = false, foundExpired = false;
        for (Asset_Summary__c summary : summaries) {
            System.assert(summary.Asset_Count__c != null && summary.Asset_Count__c > 0, 'Asset_Count__c should be positive');
            if (summary.Asset_Type__c == 'Hardware' && summary.Account__c == accounts[2].Id) {
                if (summary.Id != null && summary.Asset_Count__c == 3) foundActive = true;
                if (summary.Id != null && summary.Asset_Count__c == 1) foundInactive = true;
            }
            if (summary.Asset_Type__c == 'Hardware' && summary.Account__c == accounts[2].Id && summary.Asset_Count__c == 1) {
                foundExpired = true;
            }
        }
        System.assert(foundActive, 'Active TriMech asset should be summarized');
        System.assert(foundInactive, 'Inactive TriMech asset should be summarized');
        System.assert(foundExpired, 'Expired TriMech asset should be summarized');

        // Test orphan cleanup: delete an asset and recalculate
        Asset assetToDelete = [SELECT Id, AccountId FROM Asset WHERE Name = 'Software Asset' LIMIT 1];
        delete assetToDelete;
        AccountAssetSummaryService.recalculate(new Set<Id>{assetToDelete.AccountId});
        List<Asset_Summary__c> orphanSummaries = [SELECT Id FROM Asset_Summary__c WHERE Account__c = :assetToDelete.AccountId];
        System.assert(orphanSummaries.size() == 0, 'Orphan Asset_Summary__c records should be deleted');
    }
}