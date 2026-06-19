public with sharing class TaskCreatorEmailService {
    
    /**
     * Sends a summary email for task creation job completion
     * @param submittedBy The user ID of the person who submitted the job
     * @param created Number of tasks created
     * @param skipped Number of tasks skipped
     * @param errors Any error messages
     * @param isLargeJob Indicates if this was a large job processed asynchronously
     * Notes:
     *  - Includes a clickable Report link with dynamic filters:
     *      fv0 = Subject (mapped or UI subject)
     *      fv1 = Run date (today, YYYY-MM-DD)
     */
    public static void sendSummaryEmail(Id submittedBy, Integer created, Integer skipped, String errors, Boolean isLargeJob, String subjectForReport) {
        if (submittedBy == null) {
            System.debug('TaskCreatorEmailService.sendSummaryEmail: submittedBy is null, skipping email');
            return;
        }
        
        // Retrieve the user to get their email
        User u = [SELECT Id, Email, IsActive, UserType FROM User WHERE Id = :submittedBy LIMIT 1];
        if (u.Email == null || u.Email == '') {
            System.debug('TaskCreatorEmailService.sendSummaryEmail: User email is null or empty, skipping email');
            return;
        }
        
        // Prepare email content
        String subject = isLargeJob ? 'Task Creation Batch Job Complete' : 'Task Creation Job Complete';
        String body = 'Task Creation Job Complete.\n\n';
        body += 'Tasks Created: ' + created + '\n';
        body += 'Tasks Skipped: ' + skipped + '\n';
        
        if (errors != null && errors != '') {
            body += '\nError Details:\n' + errors + '\n';
        }

        // Build dynamic report URL with fv0 (subject) and fv1 (today's date)
        String reportBase = 'https://trimech12345.lightning.force.com/lightning/r/Report/00OPZ00000Fsogj2AB/view';
        String todayIso = String.valueOf(Date.today()); // YYYY-MM-DD
        // Use the subject provided by caller (from UI mapping or first non-empty in payload). Fallback to 'Task' if blank.
        String subjectFilter = String.isBlank(subjectForReport) ? 'Task' : subjectForReport;
        String fv0 = EncodingUtil.urlEncode(subjectFilter, 'UTF-8');
        String fv1 = EncodingUtil.urlEncode(todayIso, 'UTF-8');
        String reportUrl = reportBase + '?fv0=' + fv0 + '&fv1=' + fv1;

        body += '\nOpen Dynamic Report:\n' + reportUrl + '\n';
        
        // Send email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { u.Email });
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        
        System.debug('TaskCreatorEmailService.sendSummaryEmail: Sending email to ' + u.Email);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        System.debug('TaskCreatorEmailService.sendSummaryEmail: sendEmail called successfully');
    }
}