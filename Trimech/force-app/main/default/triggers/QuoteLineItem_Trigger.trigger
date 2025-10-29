/************************************************************** 
* Trigger on all actions for Quote Line Item.
* All actions defined in QuoteLineItem_Trigger.class
* 
***************************************************************/
trigger QuoteLineItem_Trigger on QuoteLineItem (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    if(trigger.isInsert){
        if(trigger.isBefore && !QuoteLineItem_Trigger.hasRunBeforeInsert){
            QuoteLineItem_Trigger.hasRunBeforeInsert = true;
            QuoteLineItem_Trigger.beforeInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
       // }else if(trigger.isAfter && !QuoteLineItem_Trigger.hasRunAfterInsert){
            //QuoteLineItem_Trigger.hasRunAfterInsert = true;
            //QuoteLineItem_Trigger.afterInsert(trigger.new,trigger.old,trigger.newMap,trigger.oldMap);
        }
        if(trigger.isAfter && !QuoteLineItem_Trigger.hasRunAfterInsert){
            QuoteLineItem_Trigger.hasRunAfterInsert = true;
            //QuoteLineItem_Trigger.afterInsert(trigger.new);
        }
    }
    
    
    //Added By Yoseph
     if(trigger.isAfter && trigger.isUpdate && !QuoteLineItem_Trigger.hasRunAfterUpdate) {
        QuoteLineItem_Trigger.hasRunAfterUpdate = true;
        // CC - uncomment the next line to update opportunity line items
        QuoteLineItem_Trigger.callFutureToUpdateOLIs(trigger.new);
        // QuoteLineItem_Trigger.afterUpdate(trigger.new);
    }
}