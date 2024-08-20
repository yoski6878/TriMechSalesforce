@isTest
private class InvocableScheduleDLRS_UnitTest {
    @isTest
    private static void InvocableScheduleDLRS_UnitTest() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
		List<dlrs__LookupRollupSummary2__mdt> dlrsList = [SELECT Id FROM dlrs__LookupRollupSummary2__mdt WHERE dlrs__ParentObject__c = 'Account' AND dlrs__Active__c = true];        

        /*dlrs__LookupRollupSummary__c rollupSummaryAccount = new dlrs__LookupRollupSummary__c();
        rollupSummaryAccount.Name = 'Test Rollup';
        rollupSummaryAccount.dlrs__ParentObject__c = 'Account';
        rollupSummaryAccount.dlrs__ChildObject__c = 'Task';
        rollupSummaryAccount.dlrs__RelationShipField__c = 'WhatId';
        rollupSummaryAccount.dlrs__FieldToAggregate__c = 'Id';
        rollupSummaryAccount.dlrs__AggregateOperation__c = 'Count';
        rollupSummaryAccount.dlrs__AggregateResultField__c = 'AnnualRevenue';
        rollupSummaryAccount.dlrs__Active__c = true;
        rollupSummaryAccount.dlrs__CalculationMode__c = 'Scheduled';
        insert rollupSummaryAccount;*/

        List<Id> idList = new List<Id>();
        for(dlrs__LookupRollupSummary2__mdt dlrs : dlrsList){
	        idList.add(dlrs.Id);
        }
        InvocableScheduleDLRS.rollupRequests flowInputs = new InvocableScheduleDLRS.rollupRequests();
        flowInputs.dlrsList = idList;
        flowInputs.delayInterval = 30;
        flowInputs.scheduledDateTime = datetime.now();

        test.startTest();
            InvocableScheduleDLRS.makeScheduledCallout(new List<InvocableScheduleDLRS.rollupRequests>{flowInputs});
        test.stopTest();
    }
}