trigger OpportunityTechnicalResourceReminder on Opportunity (before update, after update) {
    if (Trigger.isBefore) {
        for (Opportunity current : Trigger.new) {
            Opportunity previous = Trigger.oldMap.get(current.Id);
            if (current.StageName != previous.StageName
                && current.Probability != null
                && current.Probability >= 50) {
                current.Technical_Resource_Warning_Acknowledged__c = false;
                current.Tech_Resource_Warning_Ack_By__c = null;
                current.Tech_Resource_Warning_Ack_At__c = null;
            }
        }
    }

    if (Trigger.isAfter) {
        OpportunityTechnicalResourceService.createOwnerReminders(Trigger.new, Trigger.oldMap);
    }
}
