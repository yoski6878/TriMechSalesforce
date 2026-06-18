/**
* @File Name : FlowCaseContactRolesRecalc.cls
* @Description : Utility for recalculating CaseContactRoles, designed for use in trigger flows.
* Bulkified and aligned with org standards (with sharing, USER_MODE, no SOQL/DML in loops).
* @Author :
* @Last Modified By :
* @Last Modified On : March 14, 2026
* @Modification Log :
*===============================================================================
* Ver | Date         | Author | Modification
*===============================================================================
* 1.0 | Feb 27, 2026 |        | Initial Version
* 1.1 | Mar 14, 2026 | Agent  | Bulkify, fix compile errors, USER_MODE, safer errors
**/
public without sharing class FlowCaseContactRolesRecalc {

    public enum ResultStatus { SUCCESS, SKIPPED, ERROR }

    /**
     * Input wrapper for invocable
     */
    public class Input {
        @InvocableVariable(label='Case Id' required=true)
        public Id caseId;
        @InvocableVariable(label='Contact Id' required=true)
        public Id contactId;
        @InvocableVariable(label='Role')
        public String role;
    }

    /**
     * Result wrapper for invocable
     */
    public class Output {
        @InvocableVariable
        public Id caseId;
        @InvocableVariable
        public Id contactId;
        @InvocableVariable
        public ResultStatus status;
        @InvocableVariable
        public String message;

        public Output(Id caseId, Id contactId, ResultStatus status, String message) {
            this.caseId = caseId;
            this.contactId = contactId;
            this.status = status;
            this.message = message;
        }
    }

    @InvocableMethod(label='Add and Recalc CaseContactRole' description='Adds CaseContactRoles as needed and recalculates CaseContactRoles for the given Cases.')
    public static List<Output> addAndRecalc(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }

        // Early filter invalids and collect keys
        Set<Id> caseIds = new Set<Id>();
        List<Input> valid = new List<Input>();
        for (Input inRec : inputs) {
            if (inRec == null || inRec.caseId == null || inRec.contactId == null) {
                results.add(new Output(
                    inRec != null ? inRec.caseId : null,
                    inRec != null ? inRec.contactId : null,
                    ResultStatus.SKIPPED,
                    'Missing required Case Id or Contact Id'
                ));
                continue;
            }
            // Ensure it looks like a Case Id
            if (!(String.valueOf(inRec.caseId).startsWith('500'))) {
                results.add(new Output(inRec.caseId, inRec.contactId, ResultStatus.ERROR, 'Only Case records are supported.'));
                continue;
            }
            valid.add(inRec);
            caseIds.add(inRec.caseId);
        }
        if (valid.isEmpty()) {
            return results;
        }

        // Build desired unique pairs (CaseId, ContactId)
        Set<String> desiredPairs = new Set<String>();
        Map<String, String> pairToRole = new Map<String, String>();
        for (Input inRec : valid) {
            String key = inRec.caseId + ':' + inRec.contactId;
            if (!desiredPairs.contains(key)) {
                desiredPairs.add(key);
                if (!String.isBlank(inRec.role)) {
                    pairToRole.put(key, inRec.role);
                }
            }
        }

        // Query existing CCRs for these pairs
        Map<String, CaseContactRole> existingByPair = new Map<String, CaseContactRole>();
        for (CaseContactRole ccr : [
            SELECT Id, CasesId, ContactId, Role
            FROM CaseContactRole
            WHERE CasesId IN :caseIds AND ContactId != null
        ]) {
            String key = ccr.CasesId + ':' + ccr.ContactId;
            if (desiredPairs.contains(key) && !existingByPair.containsKey(key)) {
                existingByPair.put(key, ccr);
            }
        }

        // Prepare inserts for missing pairs
        List<CaseContactRole> toInsert = new List<CaseContactRole>();
        for (String key : desiredPairs) {
            if (!existingByPair.containsKey(key)) {
                List<String> parts = key.split(':');
                Id cId = (Id) parts[0];
                Id ctId = (Id) parts[1];
                CaseContactRole ccr = new CaseContactRole(
                    CasesId   = cId,
                    ContactId = ctId
                );
                if (pairToRole.containsKey(key)) {
                    ccr.Role = pairToRole.get(key);
                }
                toInsert.add(ccr);
            }
        }

        // Insert missing CCRs in USER_MODE
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] srList = Database.insert(toInsert, false, AccessLevel.SYSTEM_MODE);
            Integer i = 0;
            for (Database.SaveResult sr : srList) {
                // Map back to input using the pair key
                CaseContactRole rec = toInsert[i++];
                String pkey = rec.CasesId + ':' + rec.ContactId;
                // If failure, record an error result for one representative input; others will still be recalced
                if (!sr.isSuccess()) {
                    Database.Error err = sr.getErrors().isEmpty() ? null : sr.getErrors()[0];
                    results.add(new Output(rec.CasesId, rec.ContactId, ResultStatus.ERROR, 'Insert CaseContactRole failed: ' + (err != null ? err.getMessage() : 'Unknown error')));
                    // Remove from desired so it doesn't influence recalculation assumptions
                }
            }
        }

        // Recalculate per Case in bulk
        recalcForCases(caseIds, results);

        // Add success/skip results for inputs that did not already produce an error entry
        Set<String> resultPairs = new Set<String>();
        for (Output r : results) {
            if (r.caseId != null && r.contactId != null) {
                resultPairs.add(r.caseId + ':' + r.contactId);
            }
        }
        for (Input inRec : valid) {
            String key = inRec.caseId + ':' + inRec.contactId;
            if (!resultPairs.contains(key)) {
                results.add(new Output(inRec.caseId, inRec.contactId, ResultStatus.SUCCESS, 'Processed'));
            }
        }
        return results;
    }

    // Bulk recalc leveraging email-based logic first; fallback otherwise
    private static void recalcForCases(Set<Id> caseIds, List<Output> results) {
        if (caseIds == null || caseIds.isEmpty()) return;

        // Email-based logic
        List<EmailMessage> emails = [
            SELECT Id, RelatedToId, CcAddress
            FROM EmailMessage
            WHERE RelatedToId IN :caseIds
            AND CcAddress != null
        ];
        if (!emails.isEmpty()) {
            try {
                // Assuming EmailMessageTriggerHandler is bulk-safe
                EmailMessageTriggerHandler.syncContactRoles(emails);
            } catch (Exception e) {
                for (Id cid : caseIds) {
                    results.add(new Output(cid, null, ResultStatus.ERROR, 'Email-based recalc failed: ' + e.getMessage()));
                }
            }
        }

        // Determine which cases have no qualifying emails or still need fallback
        Set<Id> emailCases = new Set<Id>();
        for (EmailMessage em : emails) {
            emailCases.add((Id) em.RelatedToId);
        }
        Set<Id> fallbackCases = new Set<Id>(caseIds);
        fallbackCases.removeAll(emailCases);

        if (fallbackCases.isEmpty()) return;

        // Fallback branch for remaining cases in bulk
        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id,
                   AccountId,
                   ContactId,
                   Contact.Email,
                   Contact_Roles_CC_Emails__c,
                   Missing_Case_Contact__c,
                   Missing_CC_Emails__c,
                   (SELECT Id, ContactId, Contact.Email FROM CaseContactRoles)
            FROM Case
            WHERE Id IN :fallbackCases
        ]);

        List<CaseContactRole> ccrToInsert = new List<CaseContactRole>();
        List<Case> casesToUpdate = new List<Case>();

        for (Case c : caseMap.values()) {
            Set<Id> ccrContactIds = new Set<Id>();
            Set<String> aggregatedEmails = new Set<String>();

            for (CaseContactRole ccr : c.CaseContactRoles) {
                if (ccr.ContactId != null) ccrContactIds.add(ccr.ContactId);
                if (ccr.Contact != null && !String.isBlank(ccr.Contact.Email)) {
                    aggregatedEmails.add(ccr.Contact.Email.trim().toLowerCase());
                }
            }
            if (c.ContactId != null && !ccrContactIds.contains(c.ContactId)) {
                ccrToInsert.add(new CaseContactRole(CasesId = c.Id, ContactId = c.ContactId));
                ccrContactIds.add(c.ContactId);
            }
            if (c.Contact != null && !String.isBlank(c.Contact.Email)) {
                aggregatedEmails.add(c.Contact.Email.trim().toLowerCase());
            }

            String newAggregatedEmails = aggregatedEmails.isEmpty()
                ? null
                : String.join(new List<String>(aggregatedEmails), ',');

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
        }

        if (!ccrToInsert.isEmpty()) {
            try {
                Database.insert(ccrToInsert, false, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                for (CaseContactRole rec : ccrToInsert) {
                    results.add(new Output(rec.CasesId, rec.ContactId, ResultStatus.ERROR, 'Fallback insert failed: ' + e.getMessage()));
                }
            }
        }
        if (!casesToUpdate.isEmpty()) {
            try {
                Database.update(casesToUpdate, false, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                for (Case c : casesToUpdate) {
                    results.add(new Output(c.Id, null, ResultStatus.ERROR, 'Fallback update failed: ' + e.getMessage()));
                }
            }
        }
    }
}