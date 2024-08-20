/************************************************************** 
* Trigger on all actions for Opportunity.
* All actions defined in Opportunity_Trigger.class
* 
***************************************************************/
trigger Opportunity_Trigger on Opportunity (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore && !Opportunity_Trigger.hasRunBeforeInsert){
            Opportunity_Trigger.hasRunBeforeInsert = true;
            Opportunity_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !Opportunity_Trigger.hasRunAfterInsert){
            Opportunity_Trigger.hasRunAfterInsert = true;
            Opportunity_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }
    }
    
    if(trigger.isUpdate){
        if(trigger.isBefore && !Opportunity_Trigger.hasRunBeforeUpdate){
            Opportunity_Trigger.hasRunBeforeUpdate = true;
            Opportunity_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !Opportunity_Trigger.hasRunAfterUpdate){
            Opportunity_Trigger.hasRunAfterUpdate = true;
            Opportunity_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }   
    
    /*if(trigger.isDelete){
        if(trigger.isBefore && !Opportunity_Trigger.hasRunBeforeDelete){
            Opportunity_Trigger.hasRunBeforeDelete = true;
            Opportunity_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !Opportunity_Trigger.hasRunAfterDelete){
            Opportunity_Trigger.hasRunAfterDelete = true;
            Opportunity_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }   
    
    if(trigger.isUndelete){
        if(trigger.isAfter && !Opportunity_Trigger.hasRunAfterUnDelete){
            Opportunity_Trigger.hasRunAfterUnDelete = true;
            Opportunity_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }*/
}