public with sharing class TaskCreatorQueueable implements Queueable, Database.AllowsCallouts {
    public List<Map<String, Object>> tasks;
    public Id submittedBy;
    public TaskCreatorQueueable(List<Map<String, Object>> tasks, Id submittedBy) {
        this.tasks = tasks;
        this.submittedBy = submittedBy;
    }
    public void execute(QueueableContext context) {
        Integer created = 0;
        Integer skipped = 0;
        String errors = '';
        Integer rowNum = 1;
        Integer BATCH_SIZE = 100;
        Integer DML_LIMIT = 1000;
        // Only process up to 10,000 records in this job
        Integer toProcess = Math.min(tasks.size(), DML_LIMIT);
        List<Map<String, Object>> thisBatch = new List<Map<String, Object>>();
        List<Map<String, Object>> remaining = new List<Map<String, Object>>();
        for (Integer i = 0; i < tasks.size(); i++) {
            if (i < toProcess) {
                thisBatch.add(tasks[i]);
            } else {
                remaining.add(tasks[i]);
            }
        }
        // Chain another job if there are more than 10,000 left (do this BEFORE any DML)
        if (!remaining.isEmpty()) {
            System.enqueueJob(new TaskCreatorQueueable(remaining, submittedBy));
        }
        List<Task> batchTasks = new List<Task>();
        for (Integer i = 0; i < thisBatch.size(); i++) {
            Map<String, Object> row = thisBatch[i];
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
                skipped++;
                errors += 'Row ' + rowNum + ': Missing or invalid OwnerId.\n';
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
                    skipped++;
                    errors += 'Row ' + rowNum + ': Invalid due date format.\n';
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
            // If batch is full or last record, insert
            if (batchTasks.size() == BATCH_SIZE || i == thisBatch.size() - 1) {
                Database.SaveResult[] results = Database.insert(batchTasks, false);
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        created++;
                    } else {
                        skipped++;
                    }
                }
                batchTasks.clear();
            }
            rowNum++;
        }
        // Optionally: store results in a custom object or send a notification to submittedBy
    }
}