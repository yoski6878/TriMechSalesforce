/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the OpportunityContactRole object.
 *
 *********************************************************/
public class OpportunityContactRole_Trigger {
    //Static booleans used by trigger to limit trigger execution to once per process
    public static Boolean hasRunBeforeInsert = false;
    public static Boolean hasRunBeforeUpdate = false;
    public static Boolean hasRunBeforeDelete = false;
    public static Boolean hasRunAfterInsert = false;
    public static Boolean hasRunAfterUpdate = false;
    public static Boolean hasRunAfterDelete = false;
    public static Boolean hasRunAfterUnDelete = false;
    
public static void beforeInsert(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
    for(OpportunityContactRole ocr : newList) {
            if(ocr.Role == null) ocr.Role = 'Decision Maker';
    }
    
}

public static void beforeUpdate(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
//Implement business logic
}

public static void beforeDelete(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
//Implement business logic
}

public static void afterInsert(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
    List<Id> oppIds = new List<Id>();
    for(OpportunityContactRole ocr : newList) {
            oppIds.add(ocr.OpportunityId);
    }
    
    if(!oppIds.isEmpty()) {
        syncPrimaryContactLookup(oppIds);
    }
}

public static void afterUpdate(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
    List<Id> oppIds = new List<Id>();
    for(OpportunityContactRole ocr : newList) {
            oppIds.add(ocr.OpportunityId);
    }
    
    if(!oppIds.isEmpty()) {
        syncPrimaryContactLookup(oppIds);
    }
}

public static void afterDelete(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
    List<Id> oppIds = new List<Id>();
    for(OpportunityContactRole ocr : oldList) {
        if(ocr.IsPrimary) {
            oppIds.add(ocr.OpportunityId);
        }
    }
    
    if(!oppIds.isEmpty()) {
        syncPrimaryContactLookup(oppIds);
    }
}

/*public static void afterUndelete(List<OpportunityContactRole> newList, List<OpportunityContactRole> oldList, Map<Id,OpportunityContactRole> newMap, Map<Id,OpportunityContactRole> oldMap) {
//Implement business logic
}*/

public static void syncPrimaryContactLookup(List<Id> oppIds) {
    //variables
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    
    //query for the opportunities with the primary contact role of each opportunity
    for(Opportunity opp : [SELECT Id, Primary_Contact__c, (SELECT Id, ContactId FROM OpportunityContactRoles WHERE IsPrimary = TRUE) FROM Opportunity WHERE Id IN :oppIds]) {
    //variables
    Id primaryContactId;
    
    //if there is a primary contact role, set it
    if(!opp.OpportunityContactRoles.isEmpty()) {
    primaryContactId = opp.OpportunityContactRoles[0].ContactId;
    }
    
    //check to see if current primary contact on opp matches actual primary contact role
    //if not, add to list of opps to update
    if(opp.Primary_Contact__c != primaryContactId) {
    oppsToUpdate.add(new Opportunity(Id=opp.Id,Primary_Contact__c=primaryContactId));
    }
    }
    
    //update opps if there are any to update
    if(!oppsToUpdate.isEmpty()) {
    update oppsToUpdate;
    }
    }
}