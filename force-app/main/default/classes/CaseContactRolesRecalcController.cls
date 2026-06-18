/**
* @File Name : CaseContactRolesRecalcController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 2, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 2, 2025 |   | Initial Version
**/
public with sharing class CaseContactRolesRecalcController {

    @AuraEnabled
    public static void recalcForCase(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }
        if (!String.valueOf(caseId).startsWith('500')) {
            throw new AuraHandledException('Only Case records are supported.');
        }

        // Try to use email-based logic first (only EmailMessages with CC)
        List<EmailMessage> emails = [
            SELECT Id, RelatedToId, CcAddress
            FROM EmailMessage
            WHERE RelatedToId = :caseId
                  AND CcAddress != null
        ];

        if (!emails.isEmpty()) {
            // Reuse the main logic
            EmailMessageTriggerHandler.syncContactRoles(emails);
        } else {
            // Fallback logic when there are no EmailMessages with CC
            handleNoEmailMessages(caseId);
        }
    }

    // Fallback for cases (typically portal) without EmailMessages with CC
    private static void handleNoEmailMessages(Id caseId) {
        Case c = [
            SELECT Id,
                   AccountId,
                   ContactId,
                   Contact.Email,
                   Contact_Roles_CC_Emails__c,
                   Missing_Case_Contact__c,
                   Missing_CC_Emails__c,
                   (SELECT Id, ContactId, Contact.Email
                    FROM CaseContactRoles)
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        List<Case> casesToUpdate = new List<Case>();
        List<CaseContactRole> ccrToInsert = new List<CaseContactRole>();

        // Gather current CaseContactRole contacts
        Set<Id> ccrContactIds = new Set<Id>();
        Set<String> aggregatedEmails = new Set<String>();

        for (CaseContactRole ccr : c.CaseContactRoles) {
            if (ccr.ContactId != null) {
                ccrContactIds.add(ccr.ContactId);
            }
            if (ccr.Contact != null && !String.isBlank(ccr.Contact.Email)) {
                aggregatedEmails.add(ccr.Contact.Email.trim().toLowerCase());
            }
        }

        // Ensure primary Contact has a CaseContactRole
        if (c.ContactId != null && !ccrContactIds.contains(c.ContactId)) {
            ccrToInsert.add(new CaseContactRole(
                CasesId   = c.Id,
                ContactId = c.ContactId
            ));
            ccrContactIds.add(c.ContactId);
        }

        // Also include primary Contact's email in the aggregated emails
        if (c.Contact != null && !String.isBlank(c.Contact.Email)) {
            aggregatedEmails.add(c.Contact.Email.trim().toLowerCase());
        }

        // Build final comma-separated string for Contact_Roles_CC_Emails__c
        String newAggregatedEmails =
            aggregatedEmails.isEmpty()
            ? null
            : String.join(new List<String>(aggregatedEmails), ',');

        // For this fallback branch, we are not computing "missing" emails from CC,
        // so we reset these flags/fields to "no missing".
        Boolean missingCaseContact = false;
        String newMissingEmails = null;

        Boolean needUpdate = false;

        if (c.Contact_Roles_CC_Emails__c != newAggregatedEmails) {
            c.Contact_Roles_CC_Emails__c = newAggregatedEmails;
            needUpdate = true;
        }
        if (c.Missing_CC_Emails__c != newMissingEmails) {
            c.Missing_CC_Emails__c = newMissingEmails;
            needUpdate = true;
        }
        if (c.Missing_Case_Contact__c != missingCaseContact) {
            c.Missing_Case_Contact__c = missingCaseContact;
            needUpdate = true;
        }

        if (needUpdate) {
            casesToUpdate.add(c);
        }

        // Insert any new CaseContactRoles (e.g., for primary Contact)
        if (!ccrToInsert.isEmpty()) {
            insert ccrToInsert;
        }

        // Ensure sharing for all CaseContactRole contacts' portal users (CspLitePortal)
       	/* if (!ccrContactIds.isEmpty()) {
            // Query portal users for these contacts
            List<User> portalUsers = [
                SELECT Id, ContactId
                FROM User
                WHERE ContactId IN :ccrContactIds
                      AND IsActive = true
                      AND UserType = 'CspLitePortal'
            ];

            if (!portalUsers.isEmpty()) {
                Set<Id> portalUserIds = new Set<Id>();
                for (User u : portalUsers) {
                    portalUserIds.add(u.Id);
                }

                // Existing shares to avoid duplicates
                Map<String, CaseShare> existingSharesByKey = new Map<String, CaseShare>();
                for (CaseShare cs : [
                    SELECT Id, CaseId, UserOrGroupId
                    FROM CaseShare
                    WHERE CaseId = :caseId
                          AND UserOrGroupId IN :portalUserIds
                ]) {
                    existingSharesByKey.put(cs.CaseId + ':' + cs.UserOrGroupId, cs);
                }

                List<CaseShare> sharesToInsert = new List<CaseShare>();
                for (User u : portalUsers) {
                    String key = caseId + ':' + u.Id;
                    if (!existingSharesByKey.containsKey(key)) {
                        sharesToInsert.add(new CaseShare(
                            CaseId          = caseId,
                            UserOrGroupId   = u.Id,
                            CaseAccessLevel = 'Read',
                            RowCause        = Schema.CaseShare.RowCause.Manual
                        ));
                    }
                }

                if (!sharesToInsert.isEmpty()) {
                    Database.SaveResult[] srList = Database.insert(sharesToInsert, false);

                    for (Integer i = 0; i < srList.size(); i++) {
                        Database.SaveResult sr = srList[i];
                        CaseShare cs = sharesToInsert[i];

                        if (sr.isSuccess()) {
                            System.debug(
                                'CaseShare INSERT SUCCESS - TempIndex=' + i +
                                ', CaseId=' + cs.CaseId +
                                ', UserOrGroupId=' + cs.UserOrGroupId +
                                ', NewId=' + sr.getId()
                            );
                        } else {
                            for (Database.Error err : sr.getErrors()) {
                                System.debug(
                                    'CaseShare INSERT ERROR - TempIndex=' + i +
                                    ', CaseId=' + cs.CaseId +
                                    ', UserOrGroupId=' + cs.UserOrGroupId +
                                    ', StatusCode=' + err.getStatusCode() +
                                    ', Message=' + err.getMessage() +
                                    ', Fields=' + err.getFields()
                                );
                            }
                        }
                    }
                }
            }
        } */

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}