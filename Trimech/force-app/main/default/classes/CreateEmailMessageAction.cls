public class CreateEmailMessageAction {
    @InvocableMethod(label='Create EmailMessage' description='Creates an EmailMessage for a Case')
    public static void createEmail(List<EmailInput> inputs) {
        List<EmailMessage> emails = new List<EmailMessage>();
        for (EmailInput input : inputs) {
            EmailMessage em = new EmailMessage();
            em.ParentId = input.caseId;
            em.Subject = 'Notify Manager for Urgent Enterprise Case After Hours';
            em.TextBody = 'Notify Manager for Urgent Enterprise Case After Hours';
            em.Status = '2'; // Sent
            em.Incoming = false;
            em.FromAddress = 'noreply@trimech.com';
            em.ToAddress = 'john.moran@trimech.com';
            emails.add(em);
        }
        if (!emails.isEmpty()) {
            insert emails;
        }
    }

    public class EmailInput {
        @InvocableVariable(label='Case Id')
        public Id caseId;
        @InvocableVariable(label='Subject')
        public String subject;
        @InvocableVariable(label='Body')
        public String body;
    }
}