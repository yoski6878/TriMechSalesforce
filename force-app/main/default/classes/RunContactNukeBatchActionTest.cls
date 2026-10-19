@isTest
private class RunContactNukeBatchActionTest {
    @isTest static void previewAndDeactivateOnlySelectedContact() {
        Contact selected = new Contact(LastName='ZZZ_TEST_Selected', NUKE__c=true);
        Contact untouched = new Contact(LastName='ZZZ_TEST_Untouched', NUKE__c=true);
        insert new List<Contact>{selected, untouched};

        RunContactNukeBatchAction.Request previewRequest = new RunContactNukeBatchAction.Request();
        previewRequest.recordId = selected.Id;
        previewRequest.operation = 'PREVIEW';
        List<RunContactNukeBatchAction.Response> preview = RunContactNukeBatchAction.run(new List<RunContactNukeBatchAction.Request>{previewRequest});
        System.assertEquals(0, preview[0].relatedRecordCount);
        System.assertEquals(false, preview[0].completed);

        RunContactNukeBatchAction.Request executeRequest = new RunContactNukeBatchAction.Request();
        executeRequest.recordId = selected.Id;
        executeRequest.operation = 'DEACTIVATE';
        List<RunContactNukeBatchAction.Response> result = RunContactNukeBatchAction.run(new List<RunContactNukeBatchAction.Request>{executeRequest});
        System.assertEquals(true, result[0].completed);

        selected = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id=:selected.Id];
        untouched = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id=:untouched.Id];
        System.assert(selected.Inactive__c && !selected.NUKE__c);
        System.assert(!untouched.Inactive__c && untouched.NUKE__c);
    }
}
