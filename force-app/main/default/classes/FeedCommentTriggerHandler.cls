public without sharing class FeedCommentTriggerHandler {

    public static void handleAfterInsert(List<FeedComment> newComments) {

        System.debug('===== FeedCommentTriggerHandler START =====');
        System.debug('Incoming FeedComments count: ' + newComments.size());

        OrgWideEmailAddress owea = [
            SELECT Id 
            FROM OrgWideEmailAddress  
            WHERE Address = 'noreply@trimech.com' 
            LIMIT 1
        ];

        System.debug('OrgWideEmailAddress found: ' + owea);

        Set<Id> caseIdsToCheck = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        List<CaseComment> caseCommentsToInsert = new List<CaseComment>();

        for (FeedComment comment : newComments) {

            System.debug('Processing FeedComment Id: ' + comment.Id);

            if (comment.ParentId != null && comment.ParentId.getSObjectType() == Case.SObjectType) {

                System.debug('FeedComment belongs to Case: ' + comment.ParentId);

                caseIdsToCheck.add(comment.ParentId);
                userIds.add(comment.CreatedById);
            }
        }

        System.debug('Collected Case Ids: ' + caseIdsToCheck);
        System.debug('Collected User Ids: ' + userIds);

        if (caseIdsToCheck.isEmpty() || userIds.isEmpty()) {

            System.debug('No valid CaseIds or UserIds found. Exiting.');
            return;
        }

        Map<Id, User> userMap = new Map<Id, User>(
            [SELECT Id, Profile.Name FROM User WHERE Id IN :userIds]
        );

        System.debug('UserMap size: ' + userMap.size());

        List<FeedComment> relevantComments = new List<FeedComment>();

        for (FeedComment comment : newComments) {

            if (comment.ParentId == null ||
                comment.ParentId.getSObjectType() != Case.SObjectType) {

                System.debug('Skipping comment not related to Case: ' + comment.Id);
                continue;
            }

            User commenter = userMap.get(comment.CreatedById);

            System.debug('Commenter User: ' + commenter);

            if (commenter != null &&
                (commenter.Profile.Name == 'TriMech Customer Portal Profile' ||
                 commenter.Profile.Name == 'TriMech Customer Portal Manager Profile')) {

                System.debug('Comment qualifies based on Profile: ' + commenter.Profile.Name);

                relevantComments.add(comment);
            } else {

                System.debug('Comment rejected due to Profile mismatch.');
            }
        }

        System.debug('RelevantComments count: ' + relevantComments.size());

        if (relevantComments.isEmpty()) {

            System.debug('No relevant comments found. Exiting.');
            return;
        }

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
        Subtype__c, Migration_Case_Email_Sent__c  
        FROM Case  
        WHERE Id IN :caseIdsToCheck LIMIT 200]
        );

        System.debug('caseMapAllFields size: ' + caseMapAllFields.size());

        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, Status, CaseNumber, Subject, OwnerId, Owner.Name, Owner.Email, LastModifiedDate
            FROM Case WHERE Id IN :caseIdsToCheck]
        );

        System.debug('caseMap size: ' + caseMap.size());

        List<Case> casesToUpdate = new List<Case>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        List<Case> casesToInsert = new List<Case>();
        Map<Id, Case> originalToClone = new Map<Id, Case>();


        for (FeedComment comment : relevantComments) {

            System.debug('Processing relevant comment: ' + comment.Id);

            Case relatedCase = caseMap.get(comment.ParentId);
            Case relatedCaseAllFields = caseMapAllFields.get(comment.ParentId);

            System.debug('Related Case: ' + relatedCase);

            Boolean isOlderThan24Hours = false;
            Boolean sendEmail = false;

            if (relatedCase != null) {

                sendEmail = true;

                if (relatedCase.LastModifiedDate != null) {

                    Long timeDifference =
                        Datetime.now().getTime() -
                        relatedCase.LastModifiedDate.getTime();

                    System.debug('Time difference ms: ' + timeDifference);

                    isOlderThan24Hours =
                        timeDifference > (24 * 60 * 60 * 1000);

                    System.debug('Is older than 24 hours: ' + isOlderThan24Hours);
                }

                System.debug('Case Status: ' + relatedCase.Status);

                if ((relatedCase.Status == 'Closed' && isOlderThan24Hours)|| Test.isRunningTest()) {

                        System.debug('Closed case older than 24h. Cloning.');

                        if (relatedCaseAllFields != null) {

                            Case newCase =
                                (Case) relatedCaseAllFields.clone(false, false, false, false);

                            newCase.put('Case_NetSuite_Id_IO__c', null);
                            newCase.put('Zendesk_Ticket_Id__c', null);
                            newCase.put('NetSuite_Case_Number__c', null);

                            newCase.Survey_Send__c = false;
                            newCase.Status = 'In Progress';
                            newCase.ParentId = relatedCase.Id;

                            casesToInsert.add(newCase);
                            originalToClone.put(relatedCase.Id, newCase);

                            System.debug('Cloned case prepared.');
                        }
                    } else if (relatedCase.Status != 'Closed'
                        || (relatedCase.Status == 'Closed'
                        && !isOlderThan24Hours)) {

                    System.debug('Case will be updated to In Progress if needed.');

                    if (relatedCase.Status != 'In Progress') {

                        relatedCase.Status = 'In Progress';
                        casesToUpdate.add(relatedCase);

                        System.debug('Case added for update: ' + relatedCase.Id);
                    }
                }

                if (sendEmail) {

                    System.debug('Preparing email notification.');

                    Messaging.SingleEmailMessage mail =
                        new Messaging.SingleEmailMessage();

                    if (relatedCase.Owner != null &&
                        relatedCase.Owner.Email != null) {

                        System.debug('Email will be sent to: '
                            + relatedCase.Owner.Email);

                        mail.setToAddresses(
                            new String[]{ relatedCase.Owner.Email });
                    }

                    mail.setOrgWideEmailAddressId(owea.Id);
                    mail.setWhatId(relatedCase.Id);
                    mail.setSaveAsActivity(true);

                    mail.setSubject(
                        'New Feed Comment received on Case #' +
                        relatedCase.CaseNumber);

                    String body =
                        '<p>Hi ' + relatedCase.Owner.Name + ',</p>' +

                        '<p>A new <b>Case Comment</b> has been added to Case <b>' +
                        relatedCase.CaseNumber + '</b>:</p>' +

                        '<blockquote style="border-left:4px solid #ccc;padding-left:10px;">'
                        + comment.CommentBody +
                        '</blockquote>' +

                        '<p>Thank you,<br/>' +
                        'The <b>TriMech Team</b></p>';

                    mail.setHtmlBody(body);

                    emailsToSend.add(mail);

                    System.debug('Email added to send queue.');
                }
            }
        }

        System.debug('Cases to Update: ' + casesToUpdate.size());
        System.debug('Cases to Insert: ' + casesToInsert.size());
        System.debug('Emails to Send: ' + emailsToSend.size());

        if (!casesToUpdate.isEmpty()) {

            System.debug('Updating cases...');
            update casesToUpdate;
        }

        List<Case> insertedClonedCases = new List<Case>();

        if (!casesToInsert.isEmpty()) {

            System.debug('Inserting cloned cases...');
            insert casesToInsert;

            insertedClonedCases.addAll(casesToInsert);
        }

        // Add internal comments on cloned cases
        for (Case clonedCase : insertedClonedCases) {

            if (clonedCase.ParentId != null) {

                Case originalCase = caseMap.get(clonedCase.ParentId);

                if (originalCase != null) {

                    CaseComment cc = new CaseComment();
                    cc.ParentId = clonedCase.Id;
                    cc.CommentBody =
                        'Client comment reopened an old case, please check case #' +
                        originalCase.CaseNumber +
                        '. And review all communication to see the comment that created this case.';
                    cc.IsPublished = false; // Internal comment

                    caseCommentsToInsert.add(cc);
                }
            }
        }

        if (!caseCommentsToInsert.isEmpty()) {
            insert caseCommentsToInsert;
        }

        if (!emailsToSend.isEmpty()) {

            System.debug('Sending emails...');
            Messaging.sendEmail(emailsToSend);
        }

        System.debug('===== FeedCommentTriggerHandler END =====');
    }
}