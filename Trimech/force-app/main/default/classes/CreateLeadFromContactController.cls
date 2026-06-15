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
    }

    /** One row of the Opportunity Team section selected in the LWC. */
    public class TeamMemberInput {
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String teamMemberRole { get; set; }
        @AuraEnabled public String accessLevel { get; set; }
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
    public static InitData getInitData(Id contactId) {
        try {
            Contact c = [
                SELECT Id, Name, AccountId, Account.Name
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            InitData data = new InitData();
            data.contactName = c.Name;
            data.accountId = c.AccountId;
            data.accountName = c.Account != null ? c.Account.Name : null;
            data.hasAccount = c.AccountId != null;
            data.defaultOppName = data.hasAccount ? c.Account.Name + ' - New Lead' : null;
            data.leadRecordTypeId = Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get('Lead')
                .getRecordTypeId();
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load contact: ' + e.getMessage());
        }
    }

    /**
     * Adds the selected Opportunity Team members (the primary purpose) and the primary
     * Contact Role to an Opportunity the LWC already created via lightning-record-edit-form.
     * Team members go in first so a secondary Contact Role failure can't undo them.
     */
    @AuraEnabled
    public static void addTeamAndContactRole(Id opportunityId, Id contactId, List<TeamMemberInput> teamMembers) {
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

        // Primary Contact Role is best-effort: the Opportunity + team are already saved,
        // and the org may have created a primary role already, so never fail the call here.
        if (contactId != null) {
            Boolean hasPrimary = [
                SELECT COUNT()
                FROM OpportunityContactRole
                WHERE OpportunityId = :opportunityId AND IsPrimary = true
            ] > 0;
            if (!hasPrimary) {
                try {
                    insert new OpportunityContactRole(
                        OpportunityId = opportunityId,
                        ContactId = contactId,
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
