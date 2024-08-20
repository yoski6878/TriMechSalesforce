/************************************************************** 
* Trigger on all actions for Order.
* All actions defined in Order_Trigger.class
* 
***************************************************************/
trigger Order_Trigger on Order (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore) Order_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Order_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    if(trigger.isUpdate){
        if(trigger.isBefore) Order_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Order_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    } 
    
    /*if(trigger.isDelete){
        if(trigger.isBefore) Order_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Order_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }   
    
    if(trigger.isUndelete){
        if(trigger.isAfter) Order_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }*/
}