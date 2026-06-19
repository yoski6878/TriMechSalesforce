// CaseReminderJob.cls
// Schedulable Apex class to send email reminders and create a Task for Case owner.
// Handles 16h (email), 32h (email), and 40h (task) reminders.
// Bulk-safe and with sharing.

public with sharing class CaseReminderJob implements Schedulable {

    // Cached Business Hours Id for this transaction
    private static Id BH_ID_CACHED;

    // Resolve Business Hours Id by name once per execution, returns null if not found/inactive
    private static Id getBusinessHoursId() {
        if (BH_ID_CACHED != null) {
            return BH_ID_CACHED;
        }
        try {
            // Lookup by Name to avoid hardcoding Ids; ensure the BH record is active
            BusinessHours bh = [
                SELECT Id
                FROM BusinessHours
                WHERE Name = 'Canada EST' AND IsActive = true
                LIMIT 1
            ];
            BH_ID_CACHED = bh.Id;
        } catch (Exception e) {
            System.debug('CaseReminderJob: Failed to resolve Business Hours "Canada EST": ' + e.getMessage());
            BH_ID_CACHED = null;
        }
        return BH_ID_CACHED;
    }

    public void execute(SchedulableContext sc) {
        // Resolve Business Hours Id; if unavailable, skip processing gracefully
        Id bhId = getBusinessHoursId();
        if (bhId == null) {
            System.debug('CaseReminderJob: Business Hours "Canada EST" not found or inactive. Skipping execution.');
            return;
        }

        System.debug('CaseReminderJob: Starting job execution.');
        // Query only Cases that need reminders or tasks
        List<Case> cases = [
            SELECT Id, OwnerId, ContactId, Subject, Business_Unit__c, CreatedDate,
                X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c,
                Account.Name, CaseNumber
            FROM Case
            WHERE Status = 'Waiting for Client'
            AND (
                X16_Hour_Reminder_Sent__c = false
                OR X32_Hour_Reminder_Sent__c = false
                OR X40_Hour_Task_Created__c = false
            )
        ];
        System.debug('CaseReminderJob: Queried ' + cases.size() + ' cases.');

        // Only consider CaseHistory entries from February 5th, 2026
        DateTime caseHistoryCutover = DateTime.newInstance(2026, 2, 5, 0, 0, 0);
        Map<Id, DateTime> waitingEnteredMap = new Map<Id, DateTime>();
        List<Id> caseIds = new List<Id>();
        for (Case c : cases) caseIds.add(c.Id);
        // Bulk query Contacts for all Cases
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases) {
            if (c.ContactId != null) contactIds.add(c.ContactId);
        }
        if (!contactIds.isEmpty()) {
            for (Contact con : [SELECT Id, Email FROM Contact WHERE Id IN :contactIds]) {
                contactMap.put(con.Id, con);
            }
        }
        // Bulk query CaseHistory as before
        if (!caseIds.isEmpty()) {
            List<CaseHistory> histories = [
                SELECT CaseId, CreatedDate, NewValue
                FROM CaseHistory
                WHERE CaseId IN :caseIds
                    AND Field = 'Status'
                    AND CreatedDate >= :caseHistoryCutover
                ORDER BY CaseId, CreatedDate DESC
            ];
            Map<Id, DateTime> tempMap = new Map<Id, DateTime>();
            Set<Id> processedCases = new Set<Id>();
            for (CaseHistory ch : histories) {
                if (ch.NewValue == 'Waiting for Client' && !processedCases.contains(ch.CaseId)) {
                    tempMap.put(ch.CaseId, ch.CreatedDate);
                    processedCases.add(ch.CaseId);
                }
            }
            waitingEnteredMap.putAll(tempMap);
        }

        Map<Id, Case> casesToUpdateMap = new Map<Id, Case>();
        List<Task> tasksToInsert = new List<Task>();

        // Preload all User Ids for owner check and email notification
        Set<Id> ownerIds = new Set<Id>();
        for (Case c : cases) {
            if (c.OwnerId != null) {
                ownerIds.add(c.OwnerId);
            }
        }
        // Query User Ids and Emails
        Map<Id, User> userMap = new Map<Id, User>();
        Set<Id> userIds = new Set<Id>();
        if (!ownerIds.isEmpty()) {
            for (User u : [SELECT Id, Email, Name FROM User WHERE Id IN :ownerIds]) {
                userIds.add(u.Id);
                userMap.put(u.Id, u);
            }
        }

        // Query EmailTemplate once
        EmailTemplate template = null;
        try {
            template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Case_Reminder' LIMIT 1];
        } catch (Exception e) {
            System.debug('Email template not found: Case_Reminder - ' + e.getMessage());
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        for (Case c : cases) {
            DateTime enteredWaiting = waitingEnteredMap.containsKey(c.Id) ? waitingEnteredMap.get(c.Id) : c.CreatedDate;
            Boolean updated = false;
            Contact con = c.ContactId != null ? contactMap.get(c.ContactId) : null;

            // Compute Business Hours-based target times (in milliseconds)
            Long msPerHour = 60L * 60L * 1000L;
            DateTime target16 = BusinessHours.addGmt(bhId, enteredWaiting, 16L * msPerHour);
            DateTime target32 = BusinessHours.addGmt(bhId, enteredWaiting, 32L * msPerHour);
            DateTime target40 = BusinessHours.addGmt(bhId, enteredWaiting, 40L * msPerHour);

            System.debug('CaseReminderJob: Case ' + c.Id + ' enteredWaiting=' + enteredWaiting + ' now=' + System.now() + ' target16=' + target16 + ' target32=' + target32 + ' target40=' + target40);
            System.debug('CaseReminderJob: Field states: X16=' + c.X16_Hour_Reminder_Sent__c + ', X32=' + c.X32_Hour_Reminder_Sent__c + ', X40=' + c.X40_Hour_Task_Created__c);

            // 16h business-hours reminder
            if (System.now() >= target16 && !c.X16_Hour_Reminder_Sent__c) {
                System.debug('CaseReminderJob: Case ' + c.Id + ' - Sending 16h reminder.');
                Messaging.SingleEmailMessage mail = buildReminderEmail(c, 16, template, con);
                if (mail != null) emailsToSend.add(mail);
                c.X16_Hour_Reminder_Sent__c = true;
                updated = true;
            }
            // 32h business-hours reminder
            if (System.now() >= target32 && !c.X32_Hour_Reminder_Sent__c) {
                System.debug('CaseReminderJob: Case ' + c.Id + ' - Sending 32h reminder.');
                Messaging.SingleEmailMessage mail = buildReminderEmail(c, 32, template, con);
                if (mail != null) emailsToSend.add(mail);
                c.X32_Hour_Reminder_Sent__c = true;
                updated = true;
            }
            // 40h business-hours task
            if (System.now() >= target40 && !c.X40_Hour_Task_Created__c) {
                System.debug('CaseReminderJob: Case ' + c.Id + ' - Creating 40h task.');
                if (userIds.contains(c.OwnerId)) {
                    tasksToInsert.add(createFollowupTask(c));
                    // Send email notification to owner
                    User ownerUser = userMap.get(c.OwnerId);
                    if (ownerUser != null && ownerUser.Email != null) {
                        Messaging.SingleEmailMessage ownerMail = buildOwner40hEmail(c, ownerUser);
                        if (ownerMail != null) emailsToSend.add(ownerMail);
                    } else {
                        System.debug('CaseReminderJob: Owner for Case ' + c.Id + ' has no email.');
                    }
                } else {
                    System.debug('Skipping Task for Case ' + c.Id + ': Owner is not a User');
                }
                c.X40_Hour_Task_Created__c = true;
                updated = true;
            }
            if (updated) {
                System.debug('CaseReminderJob: Case ' + c.Id + ' - Marked for update.');
                casesToUpdateMap.put(c.Id, c);
            }
        }
        // Send emails in batches of 10
        Integer batchSize = 10;
        for (Integer i = 0; i < emailsToSend.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, emailsToSend.size());
            List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(emailsToSend[j]);
            }
            try {
                Messaging.sendEmail(batch);
                System.debug('CaseReminderJob: Sent batch of ' + batch.size() + ' emails.');
            } catch (Exception e) {
                System.debug('Failed to send batch email: ' + e.getMessage());
            }
        }
        if (!casesToUpdateMap.isEmpty()) {
            List<Case> casesToUpdate = casesToUpdateMap.values();
            Database.SaveResult[] results = Database.update(casesToUpdate, false);
            Integer successCount = 0;
            for (Integer idx = 0; idx < results.size(); idx++) {
                Database.SaveResult sr = results[idx];
                Case c = casesToUpdate[idx];
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('CaseReminderJob: Failed to update Case ' + c.Id + ': ' + err.getStatusCode() + ' - ' + err.getMessage());
                        // Optionally, insert a custom log record here:
                        // CaseReminder_Log__c log = new CaseReminder_Log__c(Case__c = c.Id, Error__c = err.getMessage(), ...);
                        // insert log;
                    }
                }
            }
            System.debug('CaseReminderJob: Cases successfully updated: ' + successCount + ' / ' + casesToUpdate.size());
        }
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
            System.debug('CaseReminderJob: Tasks inserted: ' + tasksToInsert.size());
        }
        System.debug('CaseReminderJob: Job execution complete.');
    }

    // ...existing code...
    // Build 40h owner notification email
    private Messaging.SingleEmailMessage buildOwner40hEmail(Case c, User ownerUser) {
        if (ownerUser == null || ownerUser.Email == null) {
            return null;
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { ownerUser.Email });
        mail.setSubject('40h Follow-up Task Created for Case ' + (c.CaseNumber != null ? c.CaseNumber : ''));
        String acctName = (c.Account != null && c.Account.Name != null) ? c.Account.Name : '';
        String caseNum = (c.CaseNumber != null) ? c.CaseNumber : '';
        String body = 'Hello ' + ownerUser.Name + ',\n\nA follow-up Task has been created for Case ' + caseNum + (acctName != '' ? ' (Account: ' + acctName + ')' : '') + '.\n\nPlease review and take necessary action.\n\nThank you.';
        mail.setPlainTextBody(body);
        mail.setWhatId(c.Id);
        mail.setSaveAsActivity(true);
        return mail;
    }
    Messaging.SingleEmailMessage buildReminderEmail(Case c, Integer hours, EmailTemplate template, Contact con) {
        if (template == null) {
            System.debug('No email template available for Case ' + c.Id);
            return null;
        }
        if (con == null || con.Email == null) {
            System.debug('Skipping Case ' + c.Id + ': Contact has no email');
            return null;
        }
        Boolean saveAsActivity = true;
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTemplateId(template.Id);
        mail.setWhatId(c.Id);
        mail.setSaveAsActivity(saveAsActivity);
        String bu = c.Business_Unit__c != null ? String.valueOf(c.Business_Unit__c) : '';
        if (bu == 'Hardware') {
            mail.setOrgWideEmailAddressId('0D2PZ00000006jl0AA');
        } else {
            mail.setOrgWideEmailAddressId('0D2PZ00000006i90AA');
        }
        if (con != null) {
            mail.setTargetObjectId(con.Id);
            mail.setTreatTargetObjectAsRecipient(true);
        }
        return mail;
        }

        private Task createFollowupTask(Case c) {
            Task t = new Task();
            t.OwnerId = c.OwnerId;
            t.WhatId = c.Id;
            if (c.ContactId != null) {
                t.WhoId = c.ContactId;
            }
            t.ActivityDate = Date.today();
            String acctName = (c.Account != null && c.Account.Name != null) ? c.Account.Name : '';
            String caseNum = (c.CaseNumber != null) ? c.CaseNumber : '';
            t.Subject = 'Call Client. | Case ' + caseNum + (acctName != '' ? ' Account: ' + acctName : '');
            t.Status = 'Not Started';
            t.Priority = 'High';
            return t;
        }
    }