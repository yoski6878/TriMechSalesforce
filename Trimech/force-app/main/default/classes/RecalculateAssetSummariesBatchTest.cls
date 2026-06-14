@isTest
public class RecalculateAssetSummariesBatchTest {
    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Batch Test Account');
        insert acc;
        Asset asset = new Asset(Name = 'Batch Test Asset', AccountId = acc.Id);
        insert asset;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Database.executeBatch(new RecalculateAssetSummariesBatch(), 200);
        Test.stopTest();
        // Add assertions as needed, e.g., check Asset_Summary__c records
    }
}