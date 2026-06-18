@isTest
private class InvocableScheduleDLRS_UnitTest {
    @isTest
    private static void InvocableScheduleDLRS_UnitTest() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Fetch active DLRS metadata for testing
        List<dlrs__LookupRollupSummary2__mdt> dlrsList = [SELECT Id 
                                                          FROM dlrs__LookupRollupSummary2__mdt 
                                                          WHERE dlrs__ParentObject__c = 'Account' 
                                                          AND dlrs__Active__c = true];

        List<Id> idList = new List<Id>();
        for (dlrs__LookupRollupSummary2__mdt dlrs : dlrsList) {
            idList.add(dlrs.Id);
        }

        InvocableScheduleDLRS.rollupRequests flowInputs = new InvocableScheduleDLRS.rollupRequests();
        flowInputs.dlrsList = idList;
        flowInputs.delayInterval = 30;
        flowInputs.scheduledDateTime = datetime.now();

        // Check if a scheduled job with the same name already exists
        String jobName = 'Account_Last_Connected_Date';
        Boolean jobExists = false;

        for (CronTrigger ct : [SELECT Id, CronJobDetail.Name 
                               FROM CronTrigger 
                               WHERE CronJobDetail.Name = :jobName]) {
            jobExists = true;
        }

        test.startTest();
        if (!jobExists) {
            // Call the method only if no job with the same name exists
            InvocableScheduleDLRS.makeScheduledCallout(new List<InvocableScheduleDLRS.rollupRequests>{flowInputs});
        } else {
            System.debug('Scheduled job with the name ' + jobName + ' already exists.');
        }
        test.stopTest();
    }
}