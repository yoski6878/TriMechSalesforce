/**
* @File Name : NukeContactBatchTest.cls
* @Description : Tests for NukeContactBatch. Uses synthetic test data only.
* @Author :
* @Last Modified By :
* @Last Modified On :
**/

@isTest
private class NukeContactBatchTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'ZZZ_TEST_Nuke_Contact_Parent');
        insert acc;

        Contact toDelete = new Contact(LastName = 'ZZZ_TEST_Nuke_ToDelete', AccountId = acc.Id, NUKE__c = true);
        Contact toKeep = new Contact(LastName = 'ZZZ_TEST_Nuke_ToKeep', AccountId = acc.Id, NUKE__c = false);
        insert new List<Contact>{ toDelete, toKeep };
    }

    @isTest
    static void testFlaggedContactsAreDeletedAndOthersSurvive() {
        Test.startTest();
        Database.executeBatch(new NukeContactBatch(), 100);
        Test.stopTest();

        List<Contact> remaining = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'ZZZ_TEST_Nuke_%'];
        System.assertEquals(1, remaining.size(), 'Only the non-flagged contact should remain.');
        System.assertEquals('ZZZ_TEST_Nuke_ToKeep', remaining[0].LastName);
    }

    @isTest
    static void testSafetyCapAbortsWithoutDeleting() {
        NukeContactBatch.SAFETY_CAP = 1; // 1 flagged contact from testSetup, flag a second to exceed the cap
        Account acc = [SELECT Id FROM Account WHERE Name = 'ZZZ_TEST_Nuke_Contact_Parent' LIMIT 1];
        Contact extra = new Contact(LastName = 'ZZZ_TEST_Nuke_Extra', AccountId = acc.Id, NUKE__c = true);
        insert extra;

        Test.startTest();
        Database.executeBatch(new NukeContactBatch(), 100);
        Test.stopTest();

        List<Contact> flaggedStillPresent = [SELECT Id FROM Contact WHERE NUKE__c = true AND LastName LIKE 'ZZZ_TEST_Nuke_%'];
        System.assertEquals(2, flaggedStillPresent.size(), 'Batch should have aborted and deleted nothing once the safety cap was exceeded.');
    }
}
