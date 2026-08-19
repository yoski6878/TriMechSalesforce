/**
* @File Name : RunContactNukeBatchActionTest.cls
* @Description : Tests for RunContactNukeBatchAction. Uses synthetic test data only.
**/

@isTest
private class RunContactNukeBatchActionTest {

    @testSetup
    static void setupTestData() {
        Contact con = new Contact(LastName = 'ZZZ_TEST_NukeAction_Contact', NUKE__c = true);
        insert con;
    }

    @isTest
    static void testRunDeletesFlaggedContact() {
        Test.startTest();
        RunContactNukeBatchAction.run();
        Test.stopTest();

        List<Contact> remaining = [SELECT Id FROM Contact WHERE LastName = 'ZZZ_TEST_NukeAction_Contact'];
        System.assertEquals(0, remaining.size(), 'The flagged Contact should have been deleted by the launched batch.');
    }
}
