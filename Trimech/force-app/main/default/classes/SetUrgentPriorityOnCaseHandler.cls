public class SetUrgentPriorityOnCaseHandler {
    // Matches standard urgent/important headers (e.g., X-Priority: 1, Importance: high)
    private static final Pattern HEADER_URGENT_PATTERN = Pattern.compile('(?i)(^|\n)[^\n]*?(priority|importance)[^\n]*?:[ \t]*(high|urgent)');
    // Matches the standalone word 'urgent' in the subject (case-insensitive)
    private static final Pattern SUBJECT_URGENT_PATTERN = Pattern.compile('(?i)\\burgent\\b');
    // Matches the standalone word 'CRITICAL' in the subject (case-insensitive)
    private static final Pattern SUBJECT_CRITICAL_PATTERN = Pattern.compile('(?i)\\bcritical\\b');

    public static void handle(List<EmailMessage> newEmails) {
        Set<Id> caseIdsToCheck = new Set<Id>();
        for (EmailMessage em : newEmails) {
            Boolean isUrgent = false;
            String headersLower = (em.Headers == null ? '' : em.Headers).toLowerCase();
            Matcher urgentMatcher = HEADER_URGENT_PATTERN.matcher(headersLower);
            if (urgentMatcher.find()) {
                isUrgent = true;
            }
            // Check for 'urgent' or 'critical' in subject
            if (!isUrgent && em.Subject != null && (
                SUBJECT_URGENT_PATTERN.matcher(em.Subject).find() ||
                SUBJECT_CRITICAL_PATTERN.matcher(em.Subject).find()
            )) {
                isUrgent = true;
            }
            Id caseId = null;
            if (isUrgent && em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
                caseId = em.ParentId;
            } else if (isUrgent && em.RelatedToId != null && em.RelatedToId.getSObjectType() == Case.SObjectType) {
                caseId = em.RelatedToId;
            }
            if (caseId != null) {
                caseIdsToCheck.add(caseId);
            }
        }
        if (!caseIdsToCheck.isEmpty()) {
            List<Case> updates = new List<Case>();
            for (Case c : [SELECT Id, Priority, Origin, Status FROM Case WHERE Id IN :caseIdsToCheck]) {
                if (c.Origin == 'Email' && c.Status == 'New' && (c.Priority == null || c.Priority != 'Urgent')) {
                    updates.add(new Case(Id = c.Id, Priority = 'Urgent'));
                }
            }
            if (!updates.isEmpty()) {
                Database.update(updates, false);
            }
        }
    }
}