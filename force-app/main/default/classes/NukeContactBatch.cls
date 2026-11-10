/**
* @File Name : NukeContactBatch.cls
* @Description : Admin-only bulk cleanup job for Contact records flagged NUKE__c = true.
*   Each Contact is checked against the NUKE rules in NukeDeactivationService:
*   Contacts with activity or a survey in the last 12 months, an Order less than
*   8 years old, or an Adobe Sign agreement are inactivated. All others are removed
*   from related records and deleted (Recycle Bin). Related records are kept active.
*   Refuses to run if more than 500 records are flagged in one go, to guard against
*   an accidental mass-edit.
*   Invoke via Execute Anonymous: Database.executeBatch(new NukeContactBatch(), 100);
* @Author :
* @Last Modified By :
* @Last Modified On :
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | | | Initial Version
* 1.1 | | | Inactivate or delete per NUKE rules; related records stay active
**/

global class NukeContactBatch implements Database.Batchable<sObject>, Database.Stateful {
    @TestVisible private static Integer SAFETY_CAP = 500;
    private String query;
    private Boolean aborted = false;
    private Integer flaggedCount = 0;
    public Integer inactivatedRecords = 0;
    public Integer deletedRecords = 0;
    public Integer failedRecords = 0;
    public List<String> csvLines = new List<String>();
    public List<String> errorLines = new List<String>();
    public List<String> assetLines = new List<String>();

    global NukeContactBatch() {
        query = 'SELECT Id FROM Contact WHERE NUKE__c = true';
        csvLines.add('Contact Id, Contact Name, NetSuite Id, Action, Reason, Assets Cleared, Opportunities Updated, Status');
        assetLines.add('Asset Id, Asset Name, Account Id, Field Cleared, Former Contact Id, Former Contact Name');

        flaggedCount = [SELECT COUNT() FROM Contact WHERE NUKE__c = true];
        if (flaggedCount > SAFETY_CAP) {
            aborted = true;
        }
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        if (aborted) {
            return Database.getQueryLocator('SELECT Id FROM Contact WHERE Id = null');
        }
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Contact> scope) {
        if (aborted) {
            return;
        }

        try {
            Set<Id> contactIds = new Map<Id, Contact>(scope).keySet();
            NukeDeactivationService.RunResult result = NukeDeactivationService.processContacts(contactIds);
            for (NukeDeactivationService.ContactResult record : result.contacts) {
                String line = record.contactId + ', ' + csv(record.name) + ', ' + csv(record.netSuiteId) + ', ' +
                    record.action + ', ' + csv(record.reason) + ', ' + record.assetsCleared + ', ' + record.opportunitiesUpdated;
                if (!record.isSuccess()) {
                    failedRecords++;
                    errorLines.add(line + ', Error: ' + csv(record.error));
                } else if (record.action == NukeDeactivationService.ACTION_DELETED) {
                    deletedRecords++;
                    csvLines.add(line + ', Success');
                } else {
                    inactivatedRecords++;
                    csvLines.add(line + ', Success');
                }
            }
            for (NukeDeactivationService.ClearedAsset asset : result.clearedAssets) {
                assetLines.add(asset.assetId + ', ' + csv(asset.assetName) + ', ' + asset.accountId + ', ' +
                    asset.fieldLabel + ', ' + asset.contactId + ', ' + csv(asset.contactName));
            }
        } catch (Exception e) {
            failedRecords += scope.size();
            errorLines.add(',,,,,,, Error in batch execution: ' + csv(e.getMessage()));
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
            email.setSubject('NUKE Contact Batch - ABORTED (safety cap exceeded)');
            email.setPlainTextBody(
                'NukeContactBatch was triggered but did NOT run.\n' +
                'Records flagged NUKE__c = true: ' + flaggedCount + '\n' +
                'Safety cap: ' + SAFETY_CAP + '\n\n' +
                'No Contacts were changed. Review the flagged records before re-running - ' +
                'this usually means a mass-edit accidentally flagged more records than intended.'
            );
            sendReport(email);
            return;
        }

        csvLines.addAll(errorLines);

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('NukedContactsReport.csv');
        attachment.setBody(Blob.valueOf(String.join(csvLines, '\n')));
        attachment.setContentType('text/csv');

        Messaging.EmailFileAttachment assetAttachment = new Messaging.EmailFileAttachment();
        assetAttachment.setFileName('AssetsThatLostContactReport.csv');
        assetAttachment.setBody(Blob.valueOf(String.join(assetLines, '\n')));
        assetAttachment.setContentType('text/csv');

        email.setSubject('NUKE Contact Batch - Report');
        email.setPlainTextBody(
            'Ad hoc NUKE Contact cleanup batch has completed.\n' +
            'Query Used: ' + query + '\n' +
            'Total Contacts Inactivated: ' + inactivatedRecords + '\n' +
            'Total Contacts Deleted: ' + deletedRecords + '\n' +
            'Total Errors: ' + failedRecords + '\n' +
            'Assets that lost their Contact: ' + (assetLines.size() - 1) + '\n\n' +
            'Related records (Opportunities, Cases, Quotes, Orders, Assets) were kept active.\n' +
            'Deleted Contacts can be restored from the Recycle Bin for 15 days.\n\n' +
            'Find attached CSV reports for details.'
        );
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment, assetAttachment });
        sendReport(email);
    }

    private static String csv(String value) {
        if (value == null) {
            return '';
        }
        return value.contains(',') || value.contains('"') ? '"' + value.replace('"', '""') + '"' : value;
    }

    // A failed report email (e.g. email deliverability off in a sandbox) must not roll back or fail the cleanup.
    private static void sendReport(Messaging.SingleEmailMessage email) {
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (EmailException e) {
            System.debug(LoggingLevel.ERROR, 'NUKE report email could not be sent: ' + e.getMessage());
        }
    }
}
