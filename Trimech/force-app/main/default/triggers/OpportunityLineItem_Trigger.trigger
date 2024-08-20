/************************************************************** 
* Trigger on all actions for Opportunity.
* All actions defined in OpportunityLineItem_Trigger.class
* 
***************************************************************/
trigger OpportunityLineItem_Trigger on OpportunityLineItem (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
   
    if(trigger.isInsert){
        if(trigger.isBefore && !OpportunityLineItem_Trigger.hasRunBeforeInsert){
            OpportunityLineItem_Trigger.hasRunBeforeInsert = true;
            OpportunityLineItem_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !OpportunityLineItem_Trigger.hasRunAfterInsert){
            OpportunityLineItem_Trigger.hasRunAfterInsert = true;
            OpportunityLineItem_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }
    }
    
    /*if(trigger.isUpdate){
        if(trigger.isBefore && !OpportunityLineItem_Trigger.hasRunBeforeUpdate){
            OpportunityLineItem_Trigger.hasRunBeforeUpdate = true;
            OpportunityLineItem_Trigger.beforeUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !OpportunityLineItem_Trigger.hasRunAfterUpdate){
            OpportunityLineItem_Trigger.hasRunAfterUpdate = true;
            OpportunityLineItem_Trigger.afterUpdate(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }*/   
    
    /*if(trigger.isDelete){
        if(trigger.isBefore && !OpportunityLineItem_Trigger.hasRunBeforeDelete){
            OpportunityLineItem_Trigger.hasRunBeforeDelete = true;
            OpportunityLineItem_Trigger.beforeDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }else if(trigger.isAfter && !OpportunityLineItem_Trigger.hasRunAfterDelete){
            OpportunityLineItem_Trigger.hasRunAfterDelete = true;
            OpportunityLineItem_Trigger.afterDelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }   
    
    if(trigger.isUndelete){
        if(trigger.isAfter && !OpportunityLineItem_Trigger.hasRunAfterUnDelete){
            OpportunityLineItem_Trigger.hasRunAfterUnDelete = true;
            OpportunityLineItem_Trigger.afterUndelete(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }      
    }*/
}