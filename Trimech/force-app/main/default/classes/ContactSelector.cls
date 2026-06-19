// Selector for Contact lookup in Flow (by Opportunity Id only)
// LWC always resolves AccountId from Opportunity before searching
// Exposed as @AuraEnabled(cacheable=true) for LWC
// Follows security, governor, and bulkification best practices

public with sharing class ContactSelector {
    @AuraEnabled(cacheable=true)
    public static Id getAccountIdFromOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required');
        }
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        return opp.AccountId;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactLookupResult> getContactsByIds(List<Id> contactIds) {
        List<ContactLookupResult> results = new List<ContactLookupResult>();
        if (contactIds == null || contactIds.isEmpty()) {
            return results;
        }
        for (Contact c : [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id IN :contactIds
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ]) {
            results.add(new ContactLookupResult(c.Id, c.Name, c.Email));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static ContactLookupResult getContactById(Id contactId) {
        if (contactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id = :contactId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (contacts.isEmpty()) {
            return null;
        }
        return new ContactLookupResult(contacts[0].Id, contacts[0].Name, contacts[0].Email);
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactLookupResult> searchContacts(
        Id accountId,
        String searchTerm,
        Integer limitSize
    ) {
        if (accountId == null) {
            throw new AuraHandledException('AccountId is required (resolved from Opportunity)');
        }
        if (limitSize == null || limitSize < 1 || limitSize > 50) {
            limitSize = 25;
        }
        String term = String.isBlank(searchTerm) ? null : '%' + searchTerm.trim() + '%';
        List<Contact> contacts;
        if (term == null) {
            contacts = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE AccountId = :accountId
                AND Inactive__c = false
                WITH SECURITY_ENFORCED
                ORDER BY Name
                LIMIT :limitSize
            ];
        } else {
            contacts = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE AccountId = :accountId
                AND Inactive__c = false
                AND (Name LIKE :term OR Email LIKE :term)
                WITH SECURITY_ENFORCED
                ORDER BY Name
                LIMIT :limitSize
            ];
        }
        List<ContactLookupResult> results = new List<ContactLookupResult>();
        for (Contact c : contacts) {
            results.add(new ContactLookupResult(c.Id, c.Name, c.Email));
        }
        return results;
    }

    // Wrapper for LWC
    public class ContactLookupResult {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        public ContactLookupResult(Id contactId, String name, String email) {
            this.contactId = contactId;
            this.name = name;
            this.email = email;
        }
    }
}