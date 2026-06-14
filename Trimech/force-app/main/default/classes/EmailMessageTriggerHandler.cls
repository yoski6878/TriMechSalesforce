public class EmailMessageTriggerHandler {

    // Mark Case emails as externally visible
    public static void setEmailsExternallyVisible(List<EmailMessage> emails) {
        if (emails == null || emails.isEmpty()) return;

        for (EmailMessage email : emails) {
            if (email.ParentId != null) {
                String parentObjectName = email.ParentId.getSObjectType().getDescribe().getName();
                if (parentObjectName == 'Case') {
                    email.IsExternallyVisible = true;
                }
            }
        }
    }
    
    // Calculate CC Emails on case
    public static void syncContactRoles(List<EmailMessage> emails) {
        if (emails == null || emails.isEmpty()) return;

        Map<Id, Set<String>> caseIdToCcEmails = new Map<Id, Set<String>>();
        Set<String> allEmails = new Set<String>();
        Set<Id> caseIds = new Set<Id>();
        Map<Id, Set<Id>> contactIdToCaseIdsForShare = new Map<Id, Set<Id>>();

        for (EmailMessage em : emails) {
            if (em.RelatedToId == null) continue;
            if (!String.valueOf(em.RelatedToId).startsWith('500')) continue;
            if (String.isBlank(em.CcAddress)) continue;

            Id caseId = (Id) em.RelatedToId;
            caseIds.add(caseId);

            Set<String> ccSet = caseIdToCcEmails.get(caseId);
            if (ccSet == null) {
                ccSet = new Set<String>();
                caseIdToCcEmails.put(caseId, ccSet);
            }

            for (String raw : em.CcAddress.split('[;,]+')) {
                if (String.isBlank(raw)) continue;
                String addr = raw.trim().toLowerCase();
                if (!String.isBlank(addr)) {
                    ccSet.add(addr);
                    allEmails.add(addr);
                }
            }
        }

        if (caseIds.isEmpty() || allEmails.isEmpty()) return;

        Map<Id, Case> caseById = new Map<Id, Case>([
            SELECT Id,
                   AccountId,
                   ContactId,
                   Contact.AccountId,
                   Contact_Roles_CC_Emails__c,
                   Missing_Case_Contact__c,
                   Missing_CC_Emails__c
            FROM Case
            WHERE Id IN :caseIds
        ]);

        Map<String, List<Contact>> emailToContacts = new Map<String, List<Contact>>();
        for (Contact con : [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE Email IN :allEmails
        ]) {
            if (String.isBlank(con.Email)) continue;
            String key = con.Email.trim().toLowerCase();
            List<Contact> listCon = emailToContacts.get(key);
            if (listCon == null) {
                listCon = new List<Contact>();
                emailToContacts.put(key, listCon);
            }
            listCon.add(con);
        }

        Map<Id, Set<Id>> caseIdToExistingContactIds = new Map<Id, Set<Id>>();
        for (CaseContactRole ccr : [
            SELECT Id, CasesId, ContactId
            FROM CaseContactRole
            WHERE CasesId IN :caseIds
        ]) {
            Set<Id> cset = caseIdToExistingContactIds.get(ccr.CasesId);
            if (cset == null) {
                cset = new Set<Id>();
                caseIdToExistingContactIds.put(ccr.CasesId, cset);
            }
            cset.add(ccr.ContactId);
        }

        List<CaseContactRole> ccrToInsert = new List<CaseContactRole>();
        List<Case> casesToUpdate = new List<Case>();

        for (Id caseId : caseIdToCcEmails.keySet()) {
            Case c = caseById.get(caseId);
            if (c == null) continue;

            Set<String> emailsForCase = caseIdToCcEmails.get(caseId);
            if (emailsForCase == null || emailsForCase.isEmpty()) continue;

            Id accountForMatch = c.AccountId;
            if (accountForMatch == null && c.ContactId != null) {
                accountForMatch = c.Contact.AccountId;
            }

            Set<Id> existingContacts =
                caseIdToExistingContactIds.containsKey(caseId)
                ? caseIdToExistingContactIds.get(caseId)
                : new Set<Id>();

            Set<String> aggregatedEmails = new Set<String>();

            if (!String.isBlank(c.Contact_Roles_CC_Emails__c)) {
                for (String raw : c.Contact_Roles_CC_Emails__c.split('[,;]+')) {
                    if (!String.isBlank(raw)) {
                        aggregatedEmails.add(raw.trim().toLowerCase());
                    }
                }
            }

            Boolean missingCaseContact = false;
            Set<String> missingEmailsSet = new Set<String>();

            for (String email : emailsForCase) {
                aggregatedEmails.add(email);
                List<Contact> matches = emailToContacts.get(email);

                if (matches == null || matches.isEmpty()) {
                    missingCaseContact = true;
                    missingEmailsSet.add(email);
                    continue;
                }

                if (accountForMatch == null) {
                    missingCaseContact = true;
                    missingEmailsSet.add(email);
                    continue;
                }

                Boolean hasAccountMatch = false;

                for (Contact con : matches) {
                    if (accountForMatch == con.AccountId) {
                        hasAccountMatch = true;

                        if (!existingContacts.contains(con.Id)) {
                            ccrToInsert.add(
                                new CaseContactRole(
                                    CasesId   = c.Id,
                                    ContactId = con.Id
                                )
                            );
                            existingContacts.add(con.Id);
                        }

                        if (c.ContactId == null || c.ContactId != con.Id) {
                            Set<Id> cset = contactIdToCaseIdsForShare.get(con.Id);
                            if (cset == null) {
                                cset = new Set<Id>();
                                contactIdToCaseIdsForShare.put(con.Id, cset);
                            }
                            cset.add(c.Id);
                        }
                    }
                }

                if (!hasAccountMatch) {
                    missingCaseContact = true;
                    missingEmailsSet.add(email);
                }
            }

            String newAggregatedEmails =
                aggregatedEmails.isEmpty()
                ? null
                : String.join(new List<String>(aggregatedEmails), ',');

            String newMissingEmails =
                missingEmailsSet.isEmpty()
                ? null
                : String.join(new List<String>(missingEmailsSet), ',');

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
        }

        if (!ccrToInsert.isEmpty()) {
            insert ccrToInsert;
        }
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

       /* if (!contactIdToCaseIdsForShare.isEmpty()) {
            Set<Id> contactIdsForShare = contactIdToCaseIdsForShare.keySet();

            Map<Id, List<User>> contactIdToUsers = new Map<Id, List<User>>();
            for (User u : [
                SELECT Id, ContactId, IsActive, UserType
                FROM User
                WHERE ContactId IN :contactIdsForShare
                      AND IsActive = true
                      AND UserType = 'CspLitePortal'
            ]) {
                List<User> uList = contactIdToUsers.get(u.ContactId);
                if (uList == null) {
                    uList = new List<User>();
                    contactIdToUsers.put(u.ContactId, uList);
                }
                uList.add(u);
            }

            if (!contactIdToUsers.isEmpty()) {
                Set<Id> allCaseIdsForShare = new Set<Id>();
                Set<Id> allUserIdsForShare = new Set<Id>();

                for (Id contactId : contactIdToCaseIdsForShare.keySet()) {
                    Set<Id> cids = contactIdToCaseIdsForShare.get(contactId);
                    if (cids != null) allCaseIdsForShare.addAll(cids);

                    List<User> users = contactIdToUsers.get(contactId);
                    if (users != null) {
                        for (User u : users) {
                            allUserIdsForShare.add(u.Id);
                        }
                    }
                }

                Map<String, CaseShare> existingSharesByKey = new Map<String, CaseShare>();
                if (!allCaseIdsForShare.isEmpty() && !allUserIdsForShare.isEmpty()) {
                    for (CaseShare cs : [
                        SELECT Id, CaseId, UserOrGroupId
                        FROM CaseShare
                        WHERE CaseId IN :allCaseIdsForShare
                              AND UserOrGroupId IN :allUserIdsForShare
                    ]) {
                        existingSharesByKey.put(cs.CaseId + ':' + cs.UserOrGroupId, cs);
                    }
                }

                List<CaseShare> sharesToInsert = new List<CaseShare>();

                for (Id contactId : contactIdToCaseIdsForShare.keySet()) {
                    List<User> users = contactIdToUsers.get(contactId);
                    if (users == null || users.isEmpty()) continue;

                    Set<Id> caseSet = contactIdToCaseIdsForShare.get(contactId);
                    if (caseSet == null || caseSet.isEmpty()) continue;

                    for (User u : users) {
                        for (Id cid : caseSet) {
                            String key = cid + ':' + u.Id;
                            if (!existingSharesByKey.containsKey(key)) {
                                sharesToInsert.add(new CaseShare(
                                    CaseId          = cid,
                                    UserOrGroupId   = u.Id,
                                    CaseAccessLevel = 'Read',
                                    RowCause        = Schema.CaseShare.RowCause.Manual
                                ));
                            }
                        }
                    }
                }

                if (!sharesToInsert.isEmpty()) {
                    Database.insert(sharesToInsert, false);
                }
            }
        } */
    }
}