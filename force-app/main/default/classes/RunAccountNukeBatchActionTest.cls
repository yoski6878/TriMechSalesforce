/**
* @File Name : RunAccountNukeBatchActionTest.cls
* @Description : Tests for RunAccountNukeBatchAction. Uses synthetic test data only.
**/

@isTest
private class RunAccountNukeBatchActionTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'ZZZ_TEST_NukeAction_Account', NUKE__c = true);
        insert acc;
    }

    @isTest
    static void testRunDeletesFlaggedAccount() {
        Test.startTest();
        RunAccountNukeBatchAction.run();
        Test.stopTest();

        List<Account> remaining = [SELECT Id FROM Account WHERE Name = 'ZZZ_TEST_NukeAction_Account'];
        System.assertEquals(0, remaining.size(), 'The flagged Account should have been deleted by the launched batch.');
    }
}
