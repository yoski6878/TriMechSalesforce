/************************************************************** 
* Trigger on all actions for Asset.
* All actions defined in Asset_Trigger.class
* 
***************************************************************/
trigger Asset_Trigger on Asset (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore) Asset_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Asset_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    if(trigger.isUpdate){
        if(trigger.isBefore) Asset_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Asset_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);     
    }   
    
    if(trigger.isDelete){
        if(trigger.isBefore) Asset_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Asset_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }   
    
    /*if(trigger.isUndelete){
        if(trigger.isAfter) Asset_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);  
    }*/
}