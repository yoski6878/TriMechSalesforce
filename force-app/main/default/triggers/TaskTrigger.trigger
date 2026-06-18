trigger TaskTrigger on Task (before insert, before update, before delete, after insert, after update, after delete, after undelete) {

    if(trigger.isInsert){
      if(trigger.isBefore) TaskTrigger.beforeInsert(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
        else if(trigger.isAfter) TaskTrigger.afterInsert(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
    }
    
    /*if(trigger.isUpdate){
        if(trigger.isBefore) TaskTrigger.beforeUpdate(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
        else if(trigger.isAfter) TaskTrigger.afterUpdate(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
    }
    
    if(trigger.isDelete){
        if(trigger.isBefore) TaskTrigger.beforeDelete(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
        else if(trigger.isAfter) TaskTrigger.afterDelete(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);
    }
    
    if(trigger.isUndelete){
      if(trigger.isAfter) TaskTrigger.afterUnDelete(trigger.new, trigger.old, trigger.newMap, trigger.oldMap);    
    }*/
}