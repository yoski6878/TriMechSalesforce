trigger productTrigger on Product2 (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    
    if(trigger.isUpdate){
      if(trigger.isBefore && !Product_Trigger.hasRunBeforeUpdate ){
          Product_Trigger.beforeUpdate(trigger.new,trigger.oldMap); 
        }
   }
    
}