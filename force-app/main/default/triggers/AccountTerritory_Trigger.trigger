/************************************************************** 
* Trigger on all actions for AccountTerritory.
* All actions defined in AccountTerritory_Trigger.class
* 
***************************************************************/
trigger AccountTerritory_Trigger on Account_Territory__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore) AccountTerritory_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) AccountTerritory_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    /*if(trigger.isUpdate){
        if(trigger.isBefore) AccountTerritory_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) AccountTerritory_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }*/   
    
    if(trigger.isDelete){
        if(trigger.isBefore) AccountTerritory_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) AccountTerritory_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }   
    
    /*if(trigger.isUndelete){
        if(trigger.isAfter) AccountTerritory_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }*/
}