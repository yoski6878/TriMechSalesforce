public class FeedCommentTriggerHandler {
    public static void handleAfterInsert(List<FeedComment> newComments) {
    Set<Id> caseIdsToCheck = new Set<Id>();
    Set<Id> userIds = new Set<Id>();

    for (FeedComment comment : newComments) {
        if (comment.ParentId != null && comment.ParentId.getSObjectType() == Case.SObjectType) {
            caseIdsToCheck.add(comment.ParentId);
            userIds.add(comment.CreatedById);
        }
    }

    if (caseIdsToCheck.isEmpty() || userIds.isEmpty()) {
        return;
    }

    // Get users with their profiles
    Map<Id, User> userMap = new Map<Id, User>(
        [SELECT Id, Profile.Name FROM User WHERE Id IN :userIds]
    );

    // Filter to keep only feedcomments by TriMech portal profile users
    List<FeedComment> relevantComments = new List<FeedComment>();
    for (FeedComment comment : newComments) {
        User commenter = userMap.get(comment.CreatedById);
        if (comment.ParentId != null &&
            comment.ParentId.getSObjectType() == Case.SObjectType &&
            commenter != null &&
            (commenter.Profile.Name == 'TriMech Customer Portal Profile' || commenter.Profile.Name == 'TriMech Customer Portal Manager Profile')) {
                relevantComments.add(comment);
        }
    }

    if (relevantComments.isEmpty()) {
        return;
    }

    // Query Cases with all fields (FIELDS(ALL)) as requested
    Map<Id, Case> caseMapAllFields = new Map<Id, Case>(
       [ SELECT Id, ContactId, AccountId, AssetId, ProductId,
       SuppliedName, SuppliedEmail, SuppliedPhone, SuppliedCompany, Type,  Reason, Origin, Language,
       Subject, Priority, Description, CurrencyIsoCode, OwnerId,
       Comments, AssetWarrantyId, Case_NetSuite_Id_IO__c, Link_to_NetSuite_Case__c,
       Assigned_To__c, NetSuite_Case_Number__c, AVA_SFCLOUD__EngineeringReqNumber__c, Issue__c, Admin_Support__c,
       PDM_Standard_S_N_Request__c, Model__c, Serial_Number__c, Maintenance_Status__c, Description_Highlight_del__c,
       Support_Profile__c, Software_Version__c, Assigned_Analyst__c, Survey_Url__c, Company_Name__c,
       ContentVersionId__c, Email__c, First_Name__c, Guest_User_FileUpload__c, Last_Name__c,
       Phone__c, Product_Name__c, Serial_number_Incorrect__c, Survey_Send__c, Business_Unit__c, User_Contact__c,
       Blog_Worthy__c, Bug_Report_BR__c, Service_Request_SR__c, Time_Used__c, Zendesk_Ticket_Id__c, Description__c,
       Subtype__c, Migration_Case_Email_Sent__c  FROM Case  WHERE Id IN :caseIdsToCheck LIMIT 200]
    );

    Map<Id, Case> caseMap = new Map<Id, Case>(
        [SELECT Id, Status, CaseNumber, Subject, OwnerId, Owner.Name, Owner.Email, LastModifiedDate
         FROM Case WHERE Id IN :caseIdsToCheck]
    );

    List<Case> casesToUpdate = new List<Case>();
    List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

    // New list to store cases that will be inserted (cloned)
    List<Case> casesToInsert = new List<Case>();
    // Keep track of mapping from original Case Id -> cloned Case (if you need to reference after insert)
    Map<Id, Case> originalToClone = new Map<Id, Case>();

    for (FeedComment comment : relevantComments) {
        Case relatedCase = caseMap.get(comment.ParentId);
        Case relatedCaseAllFields = caseMapAllFields.get(comment.ParentId);
        Boolean isOlderThan24Hours = false;
        Boolean sendEmail = false;

        if (relatedCase != null) {
            if (relatedCase.LastModifiedDate != null) {
                Long timeDifference = Datetime.now().getTime() - relatedCase.LastModifiedDate.getTime();
                isOlderThan24Hours = timeDifference > (24 * 60 * 60 * 1000);
            }

            if (relatedCase.Status == 'Closed' && isOlderThan24Hours) {
                if (relatedCaseAllFields != null) {
                    Case newCase = (Case) relatedCaseAllFields.clone(false, false, false, false);

                    newCase.put('Case_NetSuite_Id_IO__c', null);
                    newCase.put('Zendesk_Ticket_Id__c', null);
                    newCase.put('NetSuite_Case_Number__c', null);
                    newCase.Survey_Send__c = false;
                    newCase.Status = 'In Progress'; // as requested
                    newCase.ParentId = relatedCase.Id; 

                    casesToInsert.add(newCase);
                    originalToClone.put(relatedCase.Id, newCase);
                }
            } else if (relatedCase.Status != 'Closed' || (relatedCase.Status == 'Closed' && !isOlderThan24Hours)) {
                if (relatedCase.Status != 'In Progress' && relatedCase.Status != 'New') {
                    relatedCase.Status = 'In Progress';
                    casesToUpdate.add(relatedCase);
                }
                sendEmail = true;
            }

            if (sendEmail) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                if (relatedCase.Owner != null && relatedCase.Owner.Email != null) {
                    mail.setToAddresses(new String[] { relatedCase.Owner.Email });
                }
                mail.setWhatId(relatedCase.Id);
                mail.setSaveAsActivity(true);
                mail.setSubject('New Feed Comment received on Case #' + relatedCase.CaseNumber);

                String body = 'Hi ' + relatedCase.Owner.Name + ',\n\n' +
                      'A new Case Comment has been added to Case ' + relatedCase.CaseNumber + ':\n\n' +
                      comment.CommentBody + '\n\n' +
                      'Thank you,\n' +
                      'The TriMech Team';

                mail.setPlainTextBody(body);
                emailsToSend.add(mail);
            }
        }
    }

    if (!casesToUpdate.isEmpty()) {
        update casesToUpdate;
    }

    List<Case> insertedClonedCases = new List<Case>();
    if (!casesToInsert.isEmpty()) {
        insert casesToInsert;
        insertedClonedCases.addAll(casesToInsert);
    }


    if (!emailsToSend.isEmpty()) {
        Messaging.sendEmail(emailsToSend);
    }
}

}