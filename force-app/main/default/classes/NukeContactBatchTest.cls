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
        Contact toInactivate = new Contact(LastName = 'ZZZ_TEST_Nuke_ToInactivate', AccountId = acc.Id, NUKE__c = true);
        Contact toKeep = new Contact(LastName = 'ZZZ_TEST_Nuke_ToKeep', AccountId = acc.Id, NUKE__c = false);
        insert new List<Contact>{ toDelete, toInactivate, toKeep };

        insert new Task(WhoId = toInactivate.Id, Subject = 'ZZZ_TEST_Nuke_Call', Status = 'Completed', ActivityDate = Date.today().addDays(-10));
    }

    @isTest
    static void testFlaggedContactsAreDeletedOrInactivatedPerRules() {
        Test.startTest();
        NukeContactBatch batch = new NukeContactBatch();
        Database.executeBatch(batch, 100);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE LastName = 'ZZZ_TEST_Nuke_ToDelete'], 'Contact with no activity should be deleted.');

        Contact inactivated = [SELECT Inactive__c, NUKE__c FROM Contact WHERE LastName = 'ZZZ_TEST_Nuke_ToInactivate' LIMIT 1];
        System.assertEquals(true, inactivated.Inactive__c);
        System.assertEquals(false, inactivated.NUKE__c);

        Contact untouched = [SELECT Inactive__c, NUKE__c FROM Contact WHERE LastName = 'ZZZ_TEST_Nuke_ToKeep' LIMIT 1];
        System.assertEquals(false, untouched.Inactive__c, 'Unflagged Contact should not change.');
    }

    @isTest
    static void testSafetyCapAbortsWithoutChanges() {
        NukeContactBatch.SAFETY_CAP = 1; // 2 flagged contacts from testSetup exceed the cap

        Test.startTest();
        Database.executeBatch(new NukeContactBatch(), 100);
        Test.stopTest();

        List<Contact> flaggedStillPresent = [SELECT Id FROM Contact WHERE NUKE__c = true AND LastName LIKE 'ZZZ_TEST_Nuke_%'];
        System.assertEquals(2, flaggedStillPresent.size(), 'Batch should have aborted and changed nothing once the safety cap was exceeded.');
    }
}
