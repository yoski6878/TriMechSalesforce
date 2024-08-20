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
    }
}