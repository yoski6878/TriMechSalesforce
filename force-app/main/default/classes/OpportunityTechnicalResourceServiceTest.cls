@IsTest
private class OpportunityTechnicalResourceServiceTest {
    @IsTest
    static void emptyOpportunitySetHasNoTechnicalResourceSplit() {
        OpportunityTechnicalResourceService.WarningStatus emptyStatus =
            OpportunityTechnicalResourceService.getWarningStatus(null);
        System.assertEquals(false, emptyStatus.showWarning);
        System.assertEquals(
            0,
            OpportunityTechnicalResourceService.hasTechnicalResourceSplit(new Set<Id>()).size()
        );
        System.assertEquals(
            0,
            OpportunityTechnicalResourceService.hasTechnicalResourceSplit(null).size()
        );
    }

    private static Opportunity createOpportunityBelowFifty() {
        OpportunityStage stage = [
            SELECT MasterLabel, DefaultProbability
            FROM OpportunityStage
            WHERE IsActive = true AND DefaultProbability < 50
            ORDER BY DefaultProbability DESC
            LIMIT 1
        ];
        Opportunity opportunity = new Opportunity(
            Name = 'Technical Resource Warning Test',
            StageName = stage.MasterLabel,
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;
        return [SELECT Id, OwnerId FROM Opportunity WHERE Id = :opportunity.Id];
    }

    @IsTest
    static void warningCanBeAcknowledged() {
        Opportunity opportunity = createOpportunityBelowFifty();
        OpportunityTechnicalResourceService.WarningStatus initialStatus =
            OpportunityTechnicalResourceService.getWarningStatus(opportunity.Id);
        System.assertEquals(false, initialStatus.showWarning);
        System.assertEquals(OpportunityTechnicalResourceService.WARNING_MESSAGE, initialStatus.message);

        Test.startTest();
        OpportunityTechnicalResourceService.acknowledgeWarning(opportunity.Id);
        Test.stopTest();

        Opportunity updated = [
            SELECT Technical_Resource_Warning_Acknowledged__c,
                Tech_Resource_Warning_Ack_By__c,
                Tech_Resource_Warning_Ack_At__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(true, updated.Technical_Resource_Warning_Acknowledged__c);
        System.assertEquals(UserInfo.getUserId(), updated.Tech_Resource_Warning_Ack_By__c);
        System.assertNotEquals(null, updated.Tech_Resource_Warning_Ack_At__c);
    }

    @IsTest
    static void stageChangeCreatesLinkedOwnerReminderAndResetsAcknowledgement() {
        Opportunity opportunity = createOpportunityBelowFifty();
        update new Opportunity(
            Id = opportunity.Id,
            Technical_Resource_Warning_Acknowledged__c = true,
            Tech_Resource_Warning_Ack_By__c = UserInfo.getUserId(),
            Tech_Resource_Warning_Ack_At__c = System.now()
        );
        OpportunityStage stage = [
            SELECT MasterLabel, DefaultProbability
            FROM OpportunityStage
            WHERE IsActive = true AND DefaultProbability >= 50
            ORDER BY DefaultProbability
            LIMIT 1
        ];

        Test.startTest();
        update new Opportunity(Id = opportunity.Id, StageName = stage.MasterLabel);
        Test.stopTest();

        Opportunity updated = [
            SELECT Technical_Resource_Warning_Acknowledged__c,
                Tech_Resource_Warning_Ack_By__c,
                Tech_Resource_Warning_Ack_At__c
            FROM Opportunity
            WHERE Id = :opportunity.Id
        ];
        System.assertEquals(false, updated.Technical_Resource_Warning_Acknowledged__c);
        System.assertEquals(null, updated.Tech_Resource_Warning_Ack_By__c);
        System.assertEquals(null, updated.Tech_Resource_Warning_Ack_At__c);

        Task reminder = [
            SELECT OwnerId, WhatId, Subject, Description
            FROM Task
            WHERE WhatId = :opportunity.Id
            AND Subject = 'Add a Technical Resource to Opportunity Splits'
            LIMIT 1
        ];
        System.assertEquals(opportunity.OwnerId, reminder.OwnerId);
        System.assertEquals(opportunity.Id, reminder.WhatId);
        System.assertEquals(OpportunityTechnicalResourceService.WARNING_MESSAGE, reminder.Description);
    }
}
