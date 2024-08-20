/************************************************************** 
* Trigger on all actions for Contact.
* All actions defined in Contact_Trigger.class
* 
***************************************************************/
trigger Contact_Trigger on Contact (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore) Contact_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Contact_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    if(trigger.isUpdate){
        if(trigger.isBefore) Contact_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Contact_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);     
    }   
    
    /*if(trigger.isDelete){
        if(trigger.isBefore) Contact_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Contact_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }   
    
    if(trigger.isUndelete){
        if(trigger.isAfter) Contact_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }*/
}