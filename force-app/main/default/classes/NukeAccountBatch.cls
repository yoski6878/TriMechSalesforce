/**
* @File Name : NukeAccountBatch.cls
* @Description : Admin-only bulk deactivation job for Account records flagged
*   NUKE__c = true. Records are retained; this class never deletes Accounts.
*   Refuses to run if more than 500 records are
*   flagged in one go, to guard against an accidental mass-edit.
*   Invoke via Execute Anonymous: Database.executeBatch(new NukeAccountBatch(), 50);
* @Author :
* @Last Modified By :
* @Last Modified On :
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | | | Initial Version
**/

global class NukeAccountBatch implements Database.Batchable<sObject>, Database.Stateful {
    @TestVisible private static Integer SAFETY_CAP = 500;
    private String query;
    private Boolean aborted = false;
    private Integer flaggedCount = 0;
    public Integer deletedRecords = 0;
    public List<String> csvLines = new List<String>();
    public List<String> errorLines = new List<String>();

    global NukeAccountBatch() {
        query = 'SELECT Id, Name, celigo_sfnsio__NetSuite_Id__c FROM Account WHERE NUKE__c = true';
        csvLines.add('Account Id, Account Name, NetSuite Id, Status');

        flaggedCount = [SELECT COUNT() FROM Account WHERE NUKE__c = true];
        if (flaggedCount > SAFETY_CAP) {
            aborted = true;
        }
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        if (aborted) {
            return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
        }
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Account> scope) {
        if (aborted) {
            return;
        }

        try {
            for (Account record : scope) {
                record.Inactive__c = true;
                record.NUKE__c = false;
            }
            Database.SaveResult[] results = Database.update(scope, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    deletedRecords++;
                    csvLines.add(scope[i].Id + ', ' + scope[i].Name + ', ' + scope[i].celigo_sfnsio__NetSuite_Id__c + ', Success');
                } else {
                    for (Database.Error err : results[i].getErrors()) {
                        errorLines.add(scope[i].Id + ', ' + scope[i].Name + ', ' + scope[i].celigo_sfnsio__NetSuite_Id__c + ', Error: ' + err.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error in batch execution: ' + e.getMessage());
        }
    }

    global void finish(Database.BatchableContext BC) {
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'noreply@trimech.com' LIMIT 1];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        if (owea.size() > 0) {
            email.setOrgWideEmailAddressId(owea.get(0).Id);
        }

        String groupName = 'Account_Cleanup_Team';
        List<String> emailList = new List<String>();

        List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :groupName AND Type = 'Regular' LIMIT 1];
        if (!groups.isEmpty()) {
            List<GroupMember> groupMembers = [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :groups[0].Id];
            Set<Id> userIds = new Set<Id>();
            for (GroupMember gm : groupMembers) {
                userIds.add(gm.UserOrGroupId);
            }
            List<User> users = [SELECT Email FROM User WHERE Id IN :userIds];
            for (User usr : users) {
                if (usr.Email != null) {
                    emailList.add(usr.Email);
                }
            }
        }

        if (emailList.isEmpty()) {
            emailList.add('yoseph.kinfu@trimech.com');
        }
        email.setToAddresses(emailList);

        if (aborted) {
            email.setSubject('NUKE Account Batch - ABORTED (safety cap exceeded)');
            email.setPlainTextBody(
                'NukeAccountBatch was triggered but did NOT run.\n' +
                'Records flagged NUKE__c = true: ' + flaggedCount + '\n' +
                'Safety cap: ' + SAFETY_CAP + '\n\n' +
                'No Accounts were changed. Review the flagged records before re-running - ' +
                'this usually means a mass-edit accidentally flagged more records than intended.'
            );
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            return;
        }

        csvLines.addAll(errorLines);
        String csvContent = String.join(csvLines, '\n');

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('NukedAccountsReport.csv');
        attachment.setBody(Blob.valueOf(csvContent));
        attachment.setContentType('text/csv');

        email.setSubject('NUKE Account Batch - Report');
        email.setPlainTextBody(
            'Ad hoc NUKE Account cleanup batch has completed.\n' +
            'Query Used: ' + query + '\n' +
            'Total Accounts Deactivated: ' + deletedRecords + '\n\n' +
            'Find attached CSV report for details.'
        );
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}
