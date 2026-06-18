trigger SetUrgentPriorityOnCase on EmailMessage (after insert) {
    List<EmailMessage> caseEmails = new List<EmailMessage>();
    for (EmailMessage em : Trigger.new) {
        // Check if ParentId or RelatedToId is a Case
        if ((em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) ||
            (em.RelatedToId != null && em.RelatedToId.getSObjectType() == Case.SObjectType)) {
            caseEmails.add(em);
        }
    }
    if (!caseEmails.isEmpty()) {
        SetUrgentPriorityOnCaseHandler.handle(caseEmails);
    }
}