public with sharing class CreateLeadFromContactController {
    /**
     * Initialization data for the Create Lead (Opportunity, Lead record type) screen.
     * Mirrors the defaults of the Create_Lead_from_Contact flow.
     */
    public class InitData {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String contactName;
        @AuraEnabled public Id leadRecordTypeId;
        @AuraEnabled public String defaultOppName;
        @AuraEnabled public Boolean hasAccount;
        @AuraEnabled public Boolean isAccount; // launched from an Account (vs a Contact)
        @AuraEnabled public Id softwareProductGroupId; // default Product Group (mirrors the flow)
    }

    /** One row of the Opportunity Team section selected in the LWC. */
    public class TeamMemberInput {
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String teamMemberRole { get; set; }
        @AuraEnabled public String accessLevel { get; set; }
    }

    /** New primary contact fields, when the Account user chose "Create New Contact". */
    public class NewContactInput {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOpportunityPicklist(String fieldApiName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.SObjectField fld = Schema.SObjectType.Opportunity.fields.getMap().get(fieldApiName);
        if (fld == null) {
            return options;
        }
        for (Schema.PicklistEntry e : fld.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                options.add(new Map<String, String>{ 'label' => e.getLabel(), 'value' => e.getValue() });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAccountContacts(Id accountId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (accountId == null) {
            return options;
        }
        for (Contact c : [SELECT Id, Name FROM Contact WHERE AccountId = :accountId ORDER BY Name]) {
            options.add(new Map<String, String>{ 'label' => c.Name, 'value' => c.Id });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiveCampaigns() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Campaign c : [
            SELECT Id, Name FROM Campaign
            WHERE IsActive = true AND Status = 'In Progress' AND EndDate >= :Date.today()
            ORDER BY Name
        ]) {
            options.add(new Map<String, String>{ 'label' => c.Name, 'value' => c.Id });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTeamRoleOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry e : OpportunityTeamMember.TeamMemberRole.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                options.add(new Map<String, String>{ 'label' => e.getLabel(), 'value' => e.getValue() });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDefaultTeamMembers() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (UserTeamMember ut : [
            SELECT User.Name, TeamMemberRole
            FROM UserTeamMember
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY User.Name
        ]) {
            result.add(new Map<String, String>{
                'name' => ut.User.Name,
                'role' => String.isBlank(ut.TeamMemberRole) ? '—' : ut.TeamMemberRole
            });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData(Id recordId) {
        try {
            InitData data = new InitData();
            data.leadRecordTypeId = Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get('Lead')
                .getRecordTypeId();

            // Default Product Group = Software (mirrors the flow's default choice).
            List<Product_Group__c> software = [
                SELECT Id FROM Product_Group__c
                WHERE Name = 'Software' AND Do_Not_Use__c = false
                LIMIT 1
            ];
            data.softwareProductGroupId = software.isEmpty() ? null : software[0].Id;

            String prefix = String.valueOf(recordId).substring(0, 3);
            if (prefix == Account.SObjectType.getDescribe().getKeyPrefix()) {
                // Launched from an Account: account is known, contact chosen in the LWC.
                Account a = [SELECT Id, Name FROM Account WHERE Id = :recordId LIMIT 1];
                data.isAccount = true;
                data.accountId = a.Id;
                data.accountName = a.Name;
                data.hasAccount = true;
                data.defaultOppName = a.Name + ' - New Lead';
            } else {
                // Launched from a Contact: account derived from the contact.
                Contact c = [
                    SELECT Id, Name, AccountId, Account.Name
                    FROM Contact
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                data.isAccount = false;
                data.contactName = c.Name;
                data.accountId = c.AccountId;
                data.accountName = c.Account != null ? c.Account.Name : null;
                data.hasAccount = c.AccountId != null;
                data.defaultOppName = data.hasAccount ? c.Account.Name + ' - New Lead' : null;
            }
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load record: ' + e.getMessage());
        }
    }

    /**
     * Adds the selected Opportunity Team members (the primary purpose) and the primary
     * Contact Role to an Opportunity the LWC already created via lightning-record-edit-form.
     * Team members go in first so a secondary Contact Role failure can't undo them.
     */
    @AuraEnabled
    public static void addTeamAndContactRole(
        Id opportunityId,
        Id contactId,
        NewContactInput newContact,
        List<TeamMemberInput> teamMembers
    ) {
        if (teamMembers != null && !teamMembers.isEmpty()) {
            Set<Id> seenUsers = new Set<Id>();
            List<OpportunityTeamMember> toInsert = new List<OpportunityTeamMember>();
            for (TeamMemberInput tm : teamMembers) {
                if (tm.userId == null || seenUsers.contains(tm.userId)) {
                    continue;
                }
                seenUsers.add(tm.userId);
                toInsert.add(new OpportunityTeamMember(
                    OpportunityId = opportunityId,
                    UserId = tm.userId,
                    TeamMemberRole = tm.teamMemberRole,
                    OpportunityAccessLevel = String.isBlank(tm.accessLevel) ? 'Read' : tm.accessLevel
                ));
            }
            if (!toInsert.isEmpty()) {
                try {
                    insert toInsert;
                } catch (Exception e) {
                    throw new AuraHandledException('Unable to add team members: ' + e.getMessage());
                }
            }
        }

        // Resolve the primary contact: an existing one, or create a new one (mirrors the
        // Account flow's "Create New Contact" path).
        Id effectiveContactId = contactId;
        if (effectiveContactId == null && newContact != null && String.isNotBlank(newContact.lastName)) {
            try {
                Id acctId = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1].AccountId;
                Contact c = new Contact(
                    AccountId = acctId,
                    FirstName = newContact.firstName,
                    LastName = newContact.lastName,
                    Email = newContact.email,
                    Phone = newContact.phone
                );
                insert c;
                effectiveContactId = c.Id;
            } catch (Exception e) {
                throw new AuraHandledException('Unable to create the new contact: ' + e.getMessage());
            }
        }

        // Primary Contact Role is best-effort: the Opportunity + team are already saved,
        // and the org may have created a primary role already, so never fail the call here.
        if (effectiveContactId != null) {
            Boolean hasPrimary = [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :opportunityId AND IsPrimary = true
            ] > 0;
            if (!hasPrimary) {
                try {
                    insert new OpportunityContactRole(
                        OpportunityId = opportunityId,
                        ContactId = effectiveContactId,
                        IsPrimary = true,
                        Role = 'Decision Maker'
                    );
                } catch (Exception e) {
                    // Swallow: team additions must stand regardless of contact-role issues.
                }
            }
        }
    }
}
