public without sharing class OpportunityTechnicalResourceService {
    public static final String TECHNICAL_RESOURCE_ROLE = 'Technical Resource';
    public static final String COMMISSIONABLE_GP_SPLIT_LABEL = 'Commissionable Gross Profit';
    public static final String WARNING_MESSAGE =
        'This Opportunity is at 50% or higher and does not have a Technical Resource in the Opportunity Splits.';

    public class WarningStatus {
        @AuraEnabled public Boolean probabilityAtLeastFifty;
        @AuraEnabled public Boolean hasTechnicalResourceSplit;
        @AuraEnabled public Boolean acknowledged;
        @AuraEnabled public Boolean showWarning;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static WarningStatus getWarningStatus(Id opportunityId) {
        WarningStatus status = new WarningStatus();
        status.probabilityAtLeastFifty = false;
        status.hasTechnicalResourceSplit = false;
        status.acknowledged = false;
        status.showWarning = false;
        status.message = WARNING_MESSAGE;
        if (opportunityId == null) {
            return status;
        }

        Opportunity opportunity = [
            SELECT Probability, Technical_Resource_Warning_Acknowledged__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        status.probabilityAtLeastFifty = opportunity.Probability != null && opportunity.Probability >= 50;
        status.acknowledged = opportunity.Technical_Resource_Warning_Acknowledged__c;
        status.hasTechnicalResourceSplit = hasTechnicalResourceSplit(new Set<Id>{ opportunityId }).contains(opportunityId);
        status.showWarning = status.probabilityAtLeastFifty
            && !status.hasTechnicalResourceSplit
            && !status.acknowledged;
        return status;
    }

    @AuraEnabled
    public static void acknowledgeWarning(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('An Opportunity is required.');
        }
        update new Opportunity(
            Id = opportunityId,
            Technical_Resource_Warning_Acknowledged__c = true,
            Tech_Resource_Warning_Ack_By__c = UserInfo.getUserId(),
            Tech_Resource_Warning_Ack_At__c = System.now()
        );
    }

    public static Set<Id> hasTechnicalResourceSplit(Set<Id> opportunityIds) {
        Set<Id> matchingOpportunityIds = new Set<Id>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return matchingOpportunityIds;
        }

        Map<Id, Set<Id>> technicalUsersByOpportunity = new Map<Id, Set<Id>>();
        for (OpportunityTeamMember member : [
            SELECT OpportunityId, UserId
            FROM OpportunityTeamMember
            WHERE OpportunityId IN :opportunityIds
            AND TeamMemberRole = :TECHNICAL_RESOURCE_ROLE
        ]) {
            if (!technicalUsersByOpportunity.containsKey(member.OpportunityId)) {
                technicalUsersByOpportunity.put(member.OpportunityId, new Set<Id>());
            }
            technicalUsersByOpportunity.get(member.OpportunityId).add(member.UserId);
        }
        if (technicalUsersByOpportunity.isEmpty()) {
            return matchingOpportunityIds;
        }

        Set<Id> commissionableSplitTypeIds = new Map<Id, OpportunitySplitType>([
            SELECT Id
            FROM OpportunitySplitType
            WHERE MasterLabel = :COMMISSIONABLE_GP_SPLIT_LABEL
            AND IsActive = true
        ]).keySet();
        if (commissionableSplitTypeIds.isEmpty()) {
            return matchingOpportunityIds;
        }

        for (OpportunitySplit split : [
            SELECT OpportunityId, SplitOwnerId
            FROM OpportunitySplit
            WHERE OpportunityId IN :technicalUsersByOpportunity.keySet()
            AND SplitTypeId IN :commissionableSplitTypeIds
            AND IsDeleted = false
        ]) {
            Set<Id> technicalUsers = technicalUsersByOpportunity.get(split.OpportunityId);
            if (technicalUsers != null && technicalUsers.contains(split.SplitOwnerId)) {
                matchingOpportunityIds.add(split.OpportunityId);
            }
        }
        return matchingOpportunityIds;
    }

    public static void createOwnerReminders(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> candidates = new Set<Id>();
        Map<Id, Opportunity> candidatesById = new Map<Id, Opportunity>();
        for (Opportunity current : newList) {
            Opportunity previous = oldMap == null ? null : oldMap.get(current.Id);
            if (previous != null
                && current.StageName != previous.StageName
                && current.Probability != null
                && current.Probability >= 50) {
                candidates.add(current.Id);
                candidatesById.put(current.Id, current);
            }
        }
        if (candidates.isEmpty()) {
            return;
        }

        Set<Id> opportunitiesWithTechnicalResource = hasTechnicalResourceSplit(candidates);
        List<Task> reminders = new List<Task>();
        for (Id opportunityId : candidates) {
            if (!opportunitiesWithTechnicalResource.contains(opportunityId)) {
                Opportunity opportunity = candidatesById.get(opportunityId);
                reminders.add(new Task(
                    OwnerId = opportunity.OwnerId,
                    WhatId = opportunity.Id,
                    Subject = 'Add a Technical Resource to Opportunity Splits',
                    Description = WARNING_MESSAGE,
                    ActivityDate = Date.today(),
                    Priority = 'Normal',
                    Status = 'Not Started'
                ));
            }
        }
        if (!reminders.isEmpty()) {
            insert reminders;
        }
    }
}
