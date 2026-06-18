trigger EmailMessageTrigger on EmailMessage (before insert, after insert, after update) {
    if(trigger.isInsert && trigger.isBefore){
        System.debug('EmailMessageTrigger: before insert fired.');
        EmailMessageTriggerHandler.setEmailsExternallyVisible(Trigger.new);   
    }
	if(trigger.isInsert && trigger.isAfter){
        System.debug('EmailMessageTrigger: after insert fired.');
        EmailMessageTriggerHandler.syncContactRoles(Trigger.new);
    }
    /*
    if(trigger.isUpdate && trigger.isAfter){
        System.debug('EmailMessageTrigger: after update fired.');
        EmailMessageTriggerHandler.forwardEligibleEmails(Trigger.new);
    }
    */
}