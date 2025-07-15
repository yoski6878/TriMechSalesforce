public class EmailMessageTriggerHandler {
    public static void setEmailsExternallyVisible(List<EmailMessage> emails) {
        for (EmailMessage email : emails) {
            if (email.ParentId != null) {
                String parentObjectName = email.ParentId.getSObjectType().getDescribe().getName();
                if (parentObjectName == 'Case') {
                    email.IsExternallyVisible = true;
                }
            }
        }
    }
}