@isTest
private class RunAccountNukeBatchActionTest {
    @isTest static void previewAndDeactivateOnlySelectedAccount() {
        Account selected = new Account(Name='ZZZ_TEST_Selected', NUKE__c=true);
        Account untouched = new Account(Name='ZZZ_TEST_Untouched', NUKE__c=true);
        insert new List<Account>{selected, untouched};
        Contact related = new Contact(LastName='ZZZ_TEST_Related', AccountId=selected.Id);
        insert related;

        RunAccountNukeBatchAction.Request previewRequest = new RunAccountNukeBatchAction.Request();
        previewRequest.recordId = selected.Id;
        previewRequest.operation = 'PREVIEW';
        List<RunAccountNukeBatchAction.Response> preview = RunAccountNukeBatchAction.run(new List<RunAccountNukeBatchAction.Request>{previewRequest});
        System.assertEquals(1, preview[0].relatedRecordCount);
        System.assertEquals(false, preview[0].completed);

        RunAccountNukeBatchAction.Request executeRequest = new RunAccountNukeBatchAction.Request();
        executeRequest.recordId = selected.Id;
        executeRequest.operation = 'DEACTIVATE';
        List<RunAccountNukeBatchAction.Response> result = RunAccountNukeBatchAction.run(new List<RunAccountNukeBatchAction.Request>{executeRequest});
        System.assertEquals(true, result[0].completed);

        selected = [SELECT Inactive__c, NUKE__c FROM Account WHERE Id=:selected.Id];
        untouched = [SELECT Inactive__c, NUKE__c FROM Account WHERE Id=:untouched.Id];
        related = [SELECT Inactive__c FROM Contact WHERE Id=:related.Id];
        System.assert(selected.Inactive__c && !selected.NUKE__c);
        System.assert(!untouched.Inactive__c && untouched.NUKE__c);
        System.assert(related.Inactive__c);
    }
}
