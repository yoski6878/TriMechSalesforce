/**
* @File Name : NukeAccountBatchTest.cls
* @Description : Tests for NukeAccountBatch. Uses synthetic test data only.
* @Author :
* @Last Modified By :
* @Last Modified On :
**/

@isTest
private class NukeAccountBatchTest {

    @testSetup
    static void setupTestData() {
        Account toDelete = new Account(Name = 'ZZZ_TEST_Nuke_ToDelete', NUKE__c = true);
        Account toKeep = new Account(Name = 'ZZZ_TEST_Nuke_ToKeep', NUKE__c = false);
        insert new List<Account>{ toDelete, toKeep };
    }

    @isTest
    static void testFlaggedAccountsAreDeletedAndOthersSurvive() {
        Test.startTest();
        Database.executeBatch(new NukeAccountBatch(), 50);
        Test.stopTest();

        List<Account> remaining = [SELECT Id, Name FROM Account WHERE Name LIKE 'ZZZ_TEST_Nuke_%'];
        System.assertEquals(1, remaining.size(), 'Only the non-flagged account should remain.');
        System.assertEquals('ZZZ_TEST_Nuke_ToKeep', remaining[0].Name);
    }

    @isTest
    static void testCascadeDeletesRelatedContact() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'ZZZ_TEST_Nuke_ToDelete' LIMIT 1];
        Contact c = new Contact(LastName = 'ZZZ_TEST_Nuke_Contact', AccountId = acc.Id);
        insert c;

        Test.startTest();
        Database.executeBatch(new NukeAccountBatch(), 50);
        Test.stopTest();

        List<Contact> remainingContacts = [SELECT Id FROM Contact WHERE Id = :c.Id];
        System.assertEquals(0, remainingContacts.size(), 'Contact should have been cascade-deleted with its Account.');
    }

    @isTest
    static void testSafetyCapAbortsWithoutDeleting() {
        NukeAccountBatch.SAFETY_CAP = 1; // only 1 flagged account exists from testSetup, so cap of 1 does NOT abort - flag a second to exceed it
        Account extra = new Account(Name = 'ZZZ_TEST_Nuke_Extra', NUKE__c = true);
        insert extra;

        Test.startTest();
        Database.executeBatch(new NukeAccountBatch(), 50);
        Test.stopTest();

        List<Account> flaggedStillPresent = [SELECT Id FROM Account WHERE NUKE__c = true AND Name LIKE 'ZZZ_TEST_Nuke_%'];
        System.assertEquals(2, flaggedStillPresent.size(), 'Batch should have aborted and deleted nothing once the safety cap was exceeded.');
    }
}
