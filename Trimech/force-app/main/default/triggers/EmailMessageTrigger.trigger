trigger EmailMessageTrigger on EmailMessage (before insert) {
    EmailMessageTriggerHandler.setEmailsExternallyVisible(Trigger.new);
}