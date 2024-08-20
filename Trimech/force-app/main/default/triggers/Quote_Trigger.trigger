/************************************************************** 
* Trigger on all actions for Quote.
* All actions defined in Quote_Trigger.class
* 
***************************************************************/
trigger Quote_Trigger on Quote (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore) Quote_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        //else if(trigger.isAfter) Quote_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }
    
    /*if(trigger.isUpdate){
        if(trigger.isBefore) Quote_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        //else if(trigger.isAfter) Quote_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);     
    }  
    
    if(trigger.isDelete){
        if(trigger.isBefore) Quote_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        else if(trigger.isAfter) Quote_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);      
    }   
    
    if(trigger.isUndelete){
        if(trigger.isAfter) Quote_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
    }*/
    
}