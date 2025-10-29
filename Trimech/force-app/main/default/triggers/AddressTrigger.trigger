trigger AddressTrigger on Address  (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
       if(trigger.isBefore) AddressTriggerHandler.beforeInsert(trigger.new);
        // if(trigger.isAfter) AddressTriggerHandler.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    if(trigger.isUpdate){
        //if(trigger.isAfter) AddressTriggerHandler.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }  

}