trigger caseTrigger on Case (before insert, before update, after update, after insert) {
    if(Trigger.isInsert && Trigger.isBefore){
        caseTriggerHandler.setCaseValue(Trigger.New , Trigger.Old, Trigger.NewMap, Trigger.OldMap);
        caseTriggerHandler.updateInProgressTime(Trigger.new, null);
    }
    if(Trigger.isUpdate && Trigger.isBefore){
       	caseTriggerHandler.setCaseValue(Trigger.New , Trigger.Old, Trigger.NewMap, Trigger.OldMap);
        caseTriggerHandler.updateInProgressTime(Trigger.new, Trigger.oldMap);
    }
    
    if(Trigger.isInsert && Trigger.isAfter){
        caseTriggerHandler.updateLatestPMDate(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isUpdate && Trigger.isAfter){
        caseTriggerHandler.updateLatestPMDate(Trigger.new, Trigger.oldMap);
    }
    
    
}