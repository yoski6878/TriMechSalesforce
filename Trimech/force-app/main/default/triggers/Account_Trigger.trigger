/************************************************************** 
* Trigger on all actions for Account.
* All actions defined in Account_Trigger.class
* 
***************************************************************/
trigger Account_Trigger on Account (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if((Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) && BridgeITEventHandler.runOnce()) {
        //BridgeITEventHandler.HandleEvent(trigger.new, trigger.old, 'account', (Trigger.isInsert) ? 'create' : 'edit');
    }

    if(trigger.isInsert){
        if(trigger.isBefore) Account_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Account_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    if(trigger.isUpdate){
        if(trigger.isBefore) Account_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Account_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);     
    }   
    
    if(trigger.isDelete){
        if(trigger.isBefore) Account_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Account_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }   
    
    /*if(trigger.isUndelete){
        if(trigger.isAfter) Account_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }*/
}