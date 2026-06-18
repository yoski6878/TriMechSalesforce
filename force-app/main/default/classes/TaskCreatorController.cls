public class TaskCreatorController {
    @AuraEnabled(cacheable=true)
    public static List<UserInfo> getLeadDevelopmentUsers() {
        List<UserInfo> users = new List<UserInfo>();
        for (User u : [SELECT Id, Name, Title FROM User WHERE IsActive = true AND Title LIKE '%Development Rep%']) {
            users.add(new UserInfo(u.Id, u.Name, u.Title));
        }
        return users;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserInfo> getAllStandardUsers() {
        List<UserInfo> users = new List<UserInfo>();
        for (User u : [SELECT Id, Name FROM User WHERE IsActive = true AND Profile.UserType = 'Standard']) {
            users.add(new UserInfo(u.Id, u.Name, null));
        }
        return users;
    }

    public class UserInfo {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Title;
        public UserInfo(Id id, String name, String title) {
            this.Id = id;
            this.Name = name;
            this.Title = title;
        }
    }
    @AuraEnabled
    public static LoadRecordsResult loadRecords(String inputSource, String reportId, String fileContent) {
        List<Map<String, Object>> validRecords = new List<Map<String, Object>>();
        Integer skipped = 0;
        String errors = '';
        try {
            if (inputSource == 'report' && String.isNotBlank(reportId)) {
                try {
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint('callout:OrgAnalyticsAPI/services/data/v60.0/analytics/reports/' + reportId);
                    req.setMethod('GET');
                    req.setHeader('Content-Type', 'application/json');
                    Http http = new Http();
                    HttpResponse res = http.send(req);
                    if (res.getStatusCode() == 200) {
                        Map<String, Object> reportResult = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                        Map<String, Object> factMap = (Map<String, Object>)reportResult.get('factMap');
                        Map<String, Object> ttt = factMap != null ? (Map<String, Object>)factMap.get('T!T') : null;
                        List<Object> factRows = ttt != null ? (List<Object>)ttt.get('rows') : new List<Object>();
                        Map<String, Object> reportMetadata = (Map<String, Object>)reportResult.get('reportMetadata');
                        List<Object> detailColumns = reportMetadata != null ? (List<Object>)reportMetadata.get('detailColumns') : new List<Object>();
                        // Resolve a human-readable label for each detail column from the extended metadata.
                        // detailColumns holds API names; reportExtendedMetadata.detailColumnInfo[apiName].label holds the display label.
                        Map<String, Object> extendedMetadata = (Map<String, Object>)reportResult.get('reportExtendedMetadata');
                        Map<String, Object> detailColumnInfo = extendedMetadata != null ? (Map<String, Object>)extendedMetadata.get('detailColumnInfo') : null;
                        List<String> columnLabels = new List<String>();
                        for (Object colObj : detailColumns) {
                            String apiName = String.valueOf(colObj);
                            String label = apiName;
                            if (detailColumnInfo != null && detailColumnInfo.get(apiName) instanceof Map<String, Object>) {
                                Object lbl = ((Map<String, Object>)detailColumnInfo.get(apiName)).get('label');
                                if (lbl != null) label = String.valueOf(lbl);
                            }
                            columnLabels.add(label);
                        }
                        // Build one generic row per report row, keyed by column label, so the UI can map any column.
                        for (Object rowObj : factRows) {
                            Map<String, Object> row = (Map<String, Object>)rowObj;
                            List<Object> dataCells = (List<Object>)row.get('dataCells');
                            Map<String, Object> record = new Map<String, Object>();
                            for (Integer i = 0; i < columnLabels.size(); i++) {
                                Object cellValue = null;
                                if (dataCells != null && i < dataCells.size() && dataCells[i] instanceof Map<String, Object>) {
                                    Map<String, Object> cell = (Map<String, Object>)dataCells[i];
                                    cellValue = cell.get('value');
                                    // Some columns (e.g. lookups) only populate the display label
                                    if (cellValue == null) cellValue = cell.get('label');
                                }
                                record.put(columnLabels[i], cellValue);
                            }
                            validRecords.add(record);
                        }
                    } else {
                        errors = 'Report fetch failed';
                    }
                } catch (Exception ex) {
                    errors = 'Analytics API error';
                }
            } else if (inputSource == 'file' && String.isNotBlank(fileContent)) {
                if (fileContent.startsWith('[')) {
                    try {
                        List<Object> jsonData = (List<Object>)JSON.deserializeUntyped(fileContent);
                        for (Object obj : jsonData) {
                            Map<String, Object> record = (Map<String, Object>)obj;
                            String contactIdRaw = (String)record.get('contactId');
                            String accountIdRaw = (String)record.get('accountId');
                            validRecords.add(new Map<String, Object>{ 'contactId' => contactIdRaw, 'accountId' => accountIdRaw });
                        }
                    } catch (Exception ex) {
                        errors = 'Error processing Excel JSON data: ' + ex.getMessage();
                    }
                } else {
                    List<String> lines = fileContent.split('\n');
                    if (lines.isEmpty()) {
                        errors = 'CSV file is empty.';
                    } else {
                        List<String> headerCols = lines[0].split(',');
                        Integer contactIdx = -1;
                        Integer accountIdx = -1;
                        for (Integer i = 0; i < headerCols.size(); i++) {
                            String col = headerCols[i].trim().toLowerCase();
                            if (col.endsWith('\r')) {
                                col = col.substring(0, col.length() - 1);
                            }
                            if (col == 'contact id' || col == 'contactid' || col == 'contact') contactIdx = i;
                            if (col == 'account id' || col == 'accountid' || col == 'account') accountIdx = i;
                        }
                        if (contactIdx == -1 && accountIdx == -1) {
                            errors = 'CSV missing Contact or Account column.';
                        } else {
                            for (Integer rowNum = 1; rowNum < lines.size(); rowNum++) {
                                List<String> cols = lines[rowNum].split(',');
                                String contactIdRaw = contactIdx >= 0 && cols.size() > contactIdx ? cols[contactIdx].trim() : null;
                                String accountIdRaw = accountIdx >= 0 && cols.size() > accountIdx ? cols[accountIdx].trim() : null;
                                if (contactIdRaw != null && contactIdRaw.endsWith('\r')) contactIdRaw = contactIdRaw.substring(0, contactIdRaw.length() - 1);
                                if (accountIdRaw != null && accountIdRaw.endsWith('\r')) accountIdRaw = accountIdRaw.substring(0, accountIdRaw.length() - 1);
                                validRecords.add(new Map<String, Object>{ 'contactId' => contactIdRaw, 'accountId' => accountIdRaw });
                            }
                        }
                    }
                }
            } else {
                errors = 'Invalid input';
            }
        } catch (Exception e) {
            errors = 'Unhandled error';
        }
        return new LoadRecordsResult(validRecords, validRecords.size(), skipped, errors);
    }

    public class LoadRecordsResult {
        @AuraEnabled public List<Map<String, Object>> validRecords;
        @AuraEnabled public Integer created;
        @AuraEnabled public Integer skipped;
        @AuraEnabled public String errors;
        public LoadRecordsResult(List<Map<String, Object>> validRecords, Integer created, Integer skipped, String errors) {
            this.validRecords = validRecords;
            this.created = created;
            this.skipped = skipped;
            this.errors = errors;
        }
    }

    @AuraEnabled
    public static TaskCreatorSummary createTasks(List<Map<String, Object>> tasks) {
        // If large job, submit to Batch Apex and return message
        Integer threshold = 200; // You can adjust this threshold
        if (tasks != null && tasks.size() > threshold) {
            Id userId = System.UserInfo.getUserId();
            Integer batchSize = 200; // Safe batch size for DLRS/triggers
            // Extract first non-empty subject from payload to use in report link
            String subjectForReport = null;
            for (Map<String, Object> rowSub : tasks) {
                String s = (String)rowSub.get('subject');
                if (s != null && s.trim() != '') { subjectForReport = s.trim(); break; }
            }
            Database.executeBatch(new TaskCreatorBatch(tasks, userId, subjectForReport), batchSize);
            // Do NOT send initial notification for large jobs; only send final summary
            // Return message to UI to indicate job submitted
            return new TaskCreatorSummary(0, 0, 'Large job submitted. Tasks will be created in the background. You will be notified when complete.');
        }
        // Otherwise, run synchronously (legacy logic)
        Integer created = 0;
        Integer skipped = 0;
        String errors = '';
        List<Task> tasksToInsert = new List<Task>();
        if (tasks == null || tasks.isEmpty()) {
            errors += 'No valid records to create tasks.\n';
            // Send email even with errors for small jobs
            TaskCreatorEmailService.sendSummaryEmail(System.UserInfo.getUserId(), 0, 0, errors, false, null);
            return new TaskCreatorSummary(0, 0, errors);
        }
        // Extract first non-empty subject from payload to use in report link
        String subjectForReport = null;
        try {
            Integer rowNum = 1;
            for (Map<String, Object> row : tasks) {
                if (subjectForReport == null) {
                    String s0 = (String)row.get('subject');
                    if (s0 != null && s0.trim() != '') subjectForReport = s0.trim();
                }
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
                // Parse date string to Date
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
                tasksToInsert.add(t);
                rowNum++;
            }
            if (!tasksToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(tasksToInsert, false);
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        created++;
                    } else {
                        skipped++;
                    }
                }
            }
        } catch (Exception e) {
            // Swallow details for end-user; admin logging could go here
            errors += 'Unexpected error occurred: ' + e.getMessage();
        }
        // Send email for small job
        TaskCreatorEmailService.sendSummaryEmail(System.UserInfo.getUserId(), created, skipped, errors, false, subjectForReport);
        return new TaskCreatorSummary(created, skipped, errors);
    }

    // Optionally: add a method to check status of background jobs or notify user when complete

    public class TaskCreatorSummary {
        @AuraEnabled public Integer created;
        @AuraEnabled public Integer skipped;
        @AuraEnabled public String errors;
        public TaskCreatorSummary(Integer created, Integer skipped, String errors) {
            this.created = created;
            this.skipped = skipped;
            this.errors = errors;
        }
    }
}