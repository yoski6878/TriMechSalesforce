trigger caseTrigger on Case (before insert, before update) {
	
    if(Trigger.isInsert && Trigger.isBefore){
        caseTriggerHandler.setCaseValue(Trigger.New , Trigger.Old, Trigger.NewMap, Trigger.OldMap);
    }
    if(Trigger.isUpdate && Trigger.isBefore){
       	caseTriggerHandler.setCaseValue(Trigger.New , Trigger.Old, Trigger.NewMap, Trigger.OldMap);
    }
 
}