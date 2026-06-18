public with sharing class TaskCreatorBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    public Id submittedBy;
    public List<Map<String, Object>> tasks;
    public Integer totalCreated = 0;
    public Integer totalSkipped = 0;
    public List<String> errorMessages = new List<String>();
    // Carry the subject to use in the summary email's report link
    public String subjectForReport;

    public TaskCreatorBatch(List<Map<String, Object>> tasks, Id submittedBy, String subjectForReport) {
        this.tasks = tasks;
        this.submittedBy = submittedBy;
        this.subjectForReport = subjectForReport;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        return tasks;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        List<Task> batchTasks = new List<Task>();
        Integer rowNum = 1;
        for (Map<String, Object> row : scope) {
            String cRaw = (String)row.get('contactId');
            String aRaw = (String)row.get('accountId');
            String oRaw = (String)row.get('ownerId');
            String subject = (String)row.get('subject');
            String dueDateStr = (String)row.get('dueDate');
            String type = (String)row.get('type');
            if (cRaw != null) cRaw = cRaw.trim();
            if (aRaw != null) aRaw = aRaw.trim();
            if (oRaw != null) oRaw = oRaw.trim();
            if (cRaw == 'null' || cRaw == '') cRaw = null;
            if (aRaw == 'null' || aRaw == '') aRaw = null;
            if (oRaw == 'null' || oRaw == '') oRaw = null;
            Boolean looksContact = (cRaw != null && cRaw.startsWith('003') && (cRaw.length() == 15 || cRaw.length() == 18));
            Boolean looksAccount = (aRaw != null && aRaw.startsWith('001') && (aRaw.length() == 15 || aRaw.length() == 18));
            Boolean looksOwner = (oRaw != null && oRaw.startsWith('005') && (oRaw.length() == 15 || oRaw.length() == 18));
            Id contactId = looksContact ? (Id)cRaw : null;
            Id accountId = looksAccount ? (Id)aRaw : null;
            Id ownerId = looksOwner ? (Id)oRaw : null;
            Boolean validOwner = (ownerId != null);
            if (!validOwner) {
                totalSkipped++;
                errorMessages.add('Row ' + rowNum + ': Missing or invalid OwnerId.');
                rowNum++;
                continue;
            }
            Task t = new Task();
            t.OwnerId = ownerId;
            t.Subject = subject;
            t.Type = type;
            if (dueDateStr != null && dueDateStr != '') {
                try {
                    t.ActivityDate = Date.valueOf(dueDateStr);
                } catch (Exception e) {
                    totalSkipped++;
                    errorMessages.add('Row ' + rowNum + ': Invalid due date format.');
                    rowNum++;
                    continue;
                }
            }
            if (accountId != null) {
                t.WhatId = accountId;
            }
            if (contactId != null) {
                t.WhoId = contactId;
            }
            batchTasks.add(t);
            rowNum++;
        }
        if (!batchTasks.isEmpty()) {
            Database.SaveResult[] results = Database.insert(batchTasks, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    totalCreated++;
                } else {
                    totalSkipped++;
                    errorMessages.add('Row ' + (i+1) + ': ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Enhanced debug logging for email troubleshooting
        System.debug('TaskCreatorBatch.finish: entered finish()');
        System.debug('TaskCreatorBatch.finish: submittedBy = ' + String.valueOf(submittedBy));
        System.debug('TaskCreatorBatch.finish: totalCreated = ' + String.valueOf(totalCreated));
        System.debug('TaskCreatorBatch.finish: totalSkipped = ' + String.valueOf(totalSkipped));
        System.debug('TaskCreatorBatch.finish: errorMessages = ' + String.valueOf(errorMessages));
        if (submittedBy == null) {
            System.debug('TaskCreatorBatch.finish: submittedBy is null, skipping email');
            return;
        }
        // Use centralized email service (will include dynamic report link with subjectForReport and today's date)
        TaskCreatorEmailService.sendSummaryEmail(submittedBy, totalCreated, totalSkipped, String.join(errorMessages, '\n'), true, subjectForReport);
    }
}