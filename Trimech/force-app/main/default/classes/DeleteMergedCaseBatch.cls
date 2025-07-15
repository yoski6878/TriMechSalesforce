/**
* @File Name : DeleteMergedCaseBatch.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 18, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 18, 2025 |   | Initial Version
**/


global class DeleteMergedCaseBatch implements Database.Batchable<sObject>, Database.Stateful {
    private String query;
    public Integer deletedRecords = 0;
    public List<String> csvLines = new List<String>();
    public List<String> errorLines = new List<String>();
    global DeleteMergedCaseBatch() {
        query = 'SELECT Id, CaseNumber,Business_Unit__c, Account.Name, Subject, MasterRecordId, MasterRecord.CaseNumber  FROM Case WHERE MasterRecordId != null ';
        csvLines.add('Case Id, Case Number,Business Unit, MasterRecordId, MasterRecord.CaseNumber,Account Name, Subject, Status');
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<Case> scope) {
        List<Case> casesToDelete = new List<Case>();
        
        for (Case c : scope) {
            casesToDelete.add(c);
        }
        
        try {
            Database.DeleteResult[] results = Database.delete(casesToDelete, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    deletedRecords++;
                    csvLines.add(casesToDelete[i].Id + ', ' + casesToDelete[i].CaseNumber + + ', ' + casesToDelete[i].Business_Unit__c +  ', ' + casesToDelete[i].MasterRecordId +', ' + casesToDelete[i].MasterRecord.CaseNumber +', ' + casesToDelete[i].Account.Name +', ' + casesToDelete[i].Subject + ', Success');
                } else {
                    for (Database.Error err : results[i].getErrors()) {
                        errorLines.add(casesToDelete[i].Id + ', ' + casesToDelete[i].CaseNumber + ', ' + casesToDelete[i].Business_Unit__c +  ', ' + casesToDelete[i].MasterRecordId +', ' + casesToDelete[i].MasterRecord.CaseNumber +', ' + casesToDelete[i].Account.Name +', ' + casesToDelete[i].Subject + ', Error: ' + err.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in batch execution: ' + e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        // Combine success and error lines into a single CSV
        csvLines.addAll(errorLines);
        String csvContent = String.join(csvLines, '\n');

		OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress where Address='noreply@trimech.com' LIMIT 1 ];
        
        // Create email attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('DeletedCasesReport.csv');
        attachment.setBody(Blob.valueOf(csvContent));
        attachment.setContentType('text/csv');

        // Send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

		if(owea.size() > 0){
			email.setOrgWideEmailAddressId(owea.get(0).Id);
		}

		String groupName = 'Cases_manager';
        List<String> emailList = new List<String>();
        
        // Get the Id of the public group
        Group errorGroup = [SELECT Id FROM Group WHERE DeveloperName = :groupName AND Type = 'Regular' LIMIT 1];
        
        // Get the User Ids associated with the group
        List<GroupMember> groupMembers = [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :errorGroup.Id];
        
        // Collect user IDs
        Set<Id> userIds = new Set<Id>();
        for (GroupMember gm : groupMembers) {
            userIds.add(gm.UserOrGroupId);
        }
        
        // Fetch all user emails in a single query
        List<User> users = [SELECT Email FROM User WHERE Id IN :userIds];
        for (User usr : users) {
            if (usr.Email != null) {
                emailList.add(usr.Email);
            }
        }

		if(emailList.size() > 0){
			email.setToAddresses(emailList);
		}else{
			email.setToAddresses(new String[] {'yoseph.kinfu@trimech.com'});
		}

        email.setSubject('Batch Delete Merged Cases - Report');
        email.setPlainTextBody('Batch job to delete merged cases has completed.\n' +
                               'Query Used: ' + query + '\n' +
                               'Total Records Deleted: ' + deletedRecords + '\n\n' +
                               'Find attached CSV report for details.');
        email.setFileAttachments(new Messaging.EmailFileAttachment[] {attachment});
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}