/************************************************************** 
* Trigger on all actions for OpportunityContactRole.
* All actions defined in OpportunityContactRole_Trigger.class
* 
***************************************************************/
trigger OpportunityContactRole_Trigger on OpportunityContactRole (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   if(trigger.isInsert){
     if(trigger.isBefore && !OpportunityContactRole_Trigger.hasRunBeforeInsert){
        OpportunityContactRole_Trigger.hasRunBeforeInsert = true;
        OpportunityContactRole_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }else if(trigger.isAfter && !OpportunityContactRole_Trigger.hasRunAfterInsert){
        OpportunityContactRole_Trigger.hasRunAfterInsert = true;
        OpportunityContactRole_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }
   }
 
   if(trigger.isUpdate){
     if(trigger.isBefore && !OpportunityContactRole_Trigger.hasRunBeforeUpdate){
        OpportunityContactRole_Trigger.hasRunBeforeUpdate = true;
        OpportunityContactRole_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }else if(trigger.isAfter && !OpportunityContactRole_Trigger.hasRunAfterUpdate){
        OpportunityContactRole_Trigger.hasRunAfterUpdate = true;
        OpportunityContactRole_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }      
   }   
      
   if(trigger.isDelete){
     if(trigger.isBefore && !OpportunityContactRole_Trigger.hasRunBeforeDelete){
        OpportunityContactRole_Trigger.hasRunBeforeDelete = true;
        OpportunityContactRole_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }else if(trigger.isAfter && !OpportunityContactRole_Trigger.hasRunAfterDelete){
        OpportunityContactRole_Trigger.hasRunAfterDelete = true;
        OpportunityContactRole_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }      
   }   
   
   /*if(trigger.isUndelete){
     if(trigger.isAfter && !OpportunityContactRole_Trigger.hasRunAfterUnDelete){
        OpportunityContactRole_Trigger.hasRunAfterUnDelete = true;
        OpportunityContactRole_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
     }      
   }*/
}