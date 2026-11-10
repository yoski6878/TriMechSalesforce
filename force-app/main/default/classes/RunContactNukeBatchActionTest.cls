@isTest
private class RunContactNukeBatchActionTest {
    private static RunContactNukeBatchAction.Response runAction(Id recordId, String operation) {
        RunContactNukeBatchAction.Request request = new RunContactNukeBatchAction.Request();
        request.recordId = recordId;
        request.operation = operation;
        return RunContactNukeBatchAction.run(new List<RunContactNukeBatchAction.Request>{ request })[0];
    }

    @isTest static void previewAndRunDeletesOnlySelectedContact() {
        Contact selected = new Contact(LastName='ZZZ_TEST_Selected', NUKE__c=true);
        Contact untouched = new Contact(LastName='ZZZ_TEST_Untouched', NUKE__c=true);
        insert new List<Contact>{selected, untouched};

        RunContactNukeBatchAction.Response preview = runAction(selected.Id, 'PREVIEW');
        System.assertEquals(0, preview.relatedRecordCount);
        System.assertEquals(NukeDeactivationService.ACTION_DELETED, preview.action);
        System.assertEquals(false, preview.completed);
        System.assertEquals(2, [SELECT COUNT() FROM Contact WHERE LastName LIKE 'ZZZ_TEST_%'], 'Preview should not change anything.');

        RunContactNukeBatchAction.Response result = runAction(selected.Id, 'RUN');
        System.assertEquals(true, result.completed);
        System.assertEquals(NukeDeactivationService.ACTION_DELETED, result.action);

        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Id = :selected.Id]);
        untouched = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id=:untouched.Id];
        System.assert(!untouched.Inactive__c && untouched.NUKE__c);
    }

    @isTest static void runInactivatesContactWithRecentActivity() {
        Contact selected = new Contact(LastName='ZZZ_TEST_Active', NUKE__c=true);
        insert selected;
        insert new Task(WhoId = selected.Id, Subject = 'ZZZ_TEST_Call', Status = 'Completed', ActivityDate = Date.today().addDays(-3));

        RunContactNukeBatchAction.Response result = runAction(selected.Id, 'RUN');
        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, result.action);
        System.assert(result.summary.contains('NOT deleted'));
        selected = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id=:selected.Id];
        System.assert(selected.Inactive__c && !selected.NUKE__c);
    }

    @isTest static void invalidOperationIsRejected() {
        Contact selected = new Contact(LastName='ZZZ_TEST_Invalid');
        insert selected;
        try {
            runAction(selected.Id, 'DEACTIVATE');
            System.assert(false, 'Expected an exception for an unknown operation.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('PREVIEW or RUN'));
        }
    }
}
