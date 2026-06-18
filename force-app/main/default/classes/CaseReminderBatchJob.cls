public with sharing class CaseReminderBatchJob implements Database.Batchable<SObject>, Database.Stateful {
    @TestVisible private static Boolean skipBusinessHoursCheck = false;

    private static final Long MS_PER_HOUR = 60L * 60L * 1000L;
    private static final Integer HOURS_FIRST_REMINDER = 16;
    private static final Integer HOURS_SECOND_REMINDER = 32;
    private static final Integer HOURS_OWNER_ESCALATION = 40;
    // CaseHistory rows older than this date are ignored when resolving when a Case entered "Waiting for Client".
    private static final DateTime CASE_HISTORY_CUTOFF = DateTime.newInstance(2026, 2, 5, 0, 0, 0);

    public String query;

    public CaseReminderBatchJob() {
        query = 'SELECT Id, OwnerId, ContactId, Subject, Business_Unit__c, CreatedDate, ' +
                'X16_Hour_Reminder_Sent__c, X32_Hour_Reminder_Sent__c, X40_Hour_Task_Created__c, ' +
                'Account.Name, CaseNumber ' +
                'FROM Case ' +
                'WHERE Status = \'Waiting for Client\' ' +
                'AND (X16_Hour_Reminder_Sent__c = false OR X32_Hour_Reminder_Sent__c = false OR X40_Hour_Task_Created__c = false)';
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    // Resolved once per batch run and reused across all execute() chunks (Database.Stateful).
    private Id bhId;
    private EmailTemplate template;
    private Boolean lookupsResolved = false;

    private void resolveLookups() {
        if (lookupsResolved) return;
        lookupsResolved = true;
        try {
            bhId = [SELECT Id FROM BusinessHours WHERE Name = 'Canada EST' AND IsActive = true LIMIT 1].Id;
        } catch (QueryException e) {
            System.debug('CaseReminderBatchJob: Failed to resolve Business Hours "Canada EST": ' + e.getMessage());
        }
        try {
            template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Case_Reminder' LIMIT 1];
        } catch (QueryException e) {
            System.debug('CaseReminderBatchJob: Email template not found: Case_Reminder - ' + e.getMessage());
        }
    }

    public void execute(Database.BatchableContext bc, List<Case> cases) {
        resolveLookups();
        System.debug('CaseReminderBatchJob: Processing ' + cases.size() + ' cases in this batch.');
        if (bhId == null) {
            System.debug('CaseReminderBatchJob: Business Hours "Canada EST" not found or inactive. Skipping batch.');
            return;
        }
        // Only process if current time is within business hours
        if (!skipBusinessHoursCheck && !BusinessHours.isWithin(bhId, System.now())) {
            System.debug('CaseReminderBatchJob: Skipping batch - outside business hours.');
            return;
        }
        Map<Id, DateTime> waitingEnteredMap = new Map<Id, DateTime>();
        List<Id> caseIds = new List<Id>();
        for (Case c : cases) caseIds.add(c.Id);
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases) {
            if (c.ContactId != null) contactIds.add(c.ContactId);
        }
        if (!contactIds.isEmpty()) {
            for (Contact con : [SELECT Id, Email, HasOptedOutOfEmail, IsEmailBounced FROM Contact WHERE Id IN :contactIds]) {
                contactMap.put(con.Id, con);
            }
        }
        if (!caseIds.isEmpty()) {
            List<CaseHistory> histories = [SELECT CaseId, CreatedDate, NewValue FROM CaseHistory WHERE CaseId IN :caseIds AND Field = 'Status' AND CreatedDate >= :CASE_HISTORY_CUTOFF ORDER BY CaseId, CreatedDate DESC];
            for (CaseHistory ch : histories) {
                if (ch.NewValue == 'Waiting for Client' && !waitingEnteredMap.containsKey(ch.CaseId)) {
                    // ORDER BY CreatedDate DESC + first-seen wins => most recent 'Waiting for Client' transition
                    waitingEnteredMap.put(ch.CaseId, ch.CreatedDate);
                }
            }
        }
        Map<Id, Case> casesToUpdateMap = new Map<Id, Case>();
        
        Set<Id> ownerIds = new Set<Id>();
        for (Case c : cases) {
            if (c.OwnerId != null) ownerIds.add(c.OwnerId);
        }
        Map<Id, User> userMap = new Map<Id, User>();
        if (!ownerIds.isEmpty()) {
            for (User u : [SELECT Id, Email, Name FROM User WHERE Id IN :ownerIds]) {
                userMap.put(u.Id, u);
            }
        }
        Map<Id, Messaging.SingleEmailMessage> emailMap = new Map<Id, Messaging.SingleEmailMessage>();
        Map<Id, Messaging.SingleEmailMessage> ownerEmailMap = new Map<Id, Messaging.SingleEmailMessage>();
        

        for (Case c : cases) {
            DateTime enteredWaiting = waitingEnteredMap.containsKey(c.Id) ? waitingEnteredMap.get(c.Id) : c.CreatedDate;
            Contact con = c.ContactId != null ? contactMap.get(c.ContactId) : null;
            DateTime target16 = BusinessHours.addGmt(bhId, enteredWaiting, HOURS_FIRST_REMINDER * MS_PER_HOUR);
            DateTime target32 = BusinessHours.addGmt(bhId, enteredWaiting, HOURS_SECOND_REMINDER * MS_PER_HOUR);
            DateTime target40 = BusinessHours.addGmt(bhId, enteredWaiting, HOURS_OWNER_ESCALATION * MS_PER_HOUR);
            try {
                // Strict milestone sequencing: 16h -> 32h -> 40h
                Boolean do16 = !c.X16_Hour_Reminder_Sent__c && System.now() >= target16;
                Boolean do32 = c.X16_Hour_Reminder_Sent__c && !c.X32_Hour_Reminder_Sent__c && System.now() >= target32;
                Boolean do40 = c.X32_Hour_Reminder_Sent__c && !c.X40_Hour_Task_Created__c && System.now() >= target40;
                Messaging.SingleEmailMessage mail = null;
                Messaging.SingleEmailMessage ownerMail = null;
                if (do16) {
                    // Only update checkbox if within business hours
                    if (skipBusinessHoursCheck || BusinessHours.isWithin(bhId, System.now())) {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 16h reminder (within business hours).');
                        Boolean contactBlocked = con != null && (con.HasOptedOutOfEmail || con.IsEmailBounced);
                        if (contactBlocked) {
                            // Contact unreachable — route an owner heads-up instead of emailing the customer
                            if (userMap.containsKey(c.OwnerId)) {
                                Messaging.SingleEmailMessage blockedMail = buildOwnerBlockedContactEmail(c, userMap.get(c.OwnerId), con);
                                if (blockedMail != null) {
                                    System.debug('CaseReminderBatchJob: 16h owner heads-up built for Case ' + c.Id + ' (contact unreachable).');
                                    ownerEmailMap.put(c.Id, blockedMail);
                                }
                            } else {
                                System.debug('CaseReminderBatchJob: 16h owner heads-up skipped for Case ' + c.Id + ' (owner is not a user).');
                            }
                            c.X16_Hour_Reminder_Sent__c = true;
                        } else {
                            mail = buildReminderEmail(c, 16, template, con);
                            if (mail != null) {
                                System.debug('CaseReminderBatchJob: 16h email built for Case ' + c.Id + '.');
                                emailMap.put(c.Id, mail);
                                c.X16_Hour_Reminder_Sent__c = true;
                            } else {
                                System.debug('CaseReminderBatchJob: 16h email NOT built for Case ' + c.Id + ' (template/con missing).');
                            }
                        }
                    } else {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 16h reminder but outside business hours. Skipping checkbox update.');
                    }
                } else if (do32) {
                    // Only update checkbox if within business hours
                    if (skipBusinessHoursCheck || BusinessHours.isWithin(bhId, System.now())) {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 32h reminder (within business hours).');
                        mail = buildReminderEmail(c, 32, template, con);
                        if (mail != null) {
                            System.debug('CaseReminderBatchJob: 32h email built for Case ' + c.Id + '.');
                            emailMap.put(c.Id, mail);
                            c.X32_Hour_Reminder_Sent__c = true;
                        } else {
                            System.debug('CaseReminderBatchJob: 32h email NOT built for Case ' + c.Id + ' (template/con missing).');
                        }
                    } else {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 32h reminder but outside business hours. Skipping checkbox update.');
                    }
                } else if (do40) {
                    // Only update checkbox and create task if within business hours
                    if (skipBusinessHoursCheck || BusinessHours.isWithin(bhId, System.now())) {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 40h task (within business hours).');
                        if (userMap.containsKey(c.OwnerId)) {
                            User ownerUser = userMap.get(c.OwnerId);
                            if (ownerUser != null && ownerUser.Email != null) {
                                ownerMail = buildOwner40hEmail(c, ownerUser);
                                if (ownerMail != null) {
                                    System.debug('CaseReminderBatchJob: 40h owner email built for Case ' + c.Id + '.');
                                    ownerEmailMap.put(c.Id, ownerMail);
                                } else {
                                    System.debug('CaseReminderBatchJob: 40h owner email NOT built for Case ' + c.Id + ' (owner/email missing).');
                                }
                            } else {
                                System.debug('CaseReminderBatchJob: 40h owner email skipped for Case ' + c.Id + ' (no owner user or email).');
                            }
                            c.X40_Hour_Task_Created__c = true;
                            c.Status = 'In Progress'; // Set case status to In Progress at 40-hour mark
                        } else {
                            System.debug('CaseReminderBatchJob: 40h task skipped for Case ' + c.Id + ' (owner is not a user).');
                        }
                    } else {
                        System.debug('CaseReminderBatchJob: Case ' + c.Id + ' eligible for 40h task but outside business hours. Skipping checkbox update and task creation.');
                    }
                }
                if (do16 || do32 || do40) {
                    casesToUpdateMap.put(c.Id, c);
                }
            } catch (Exception e) {
                System.debug('CaseReminderBatchJob: Skipped Case ' + c.Id + ' due to error: ' + e.getMessage());
                // Optionally: add custom error handling or notification here
            }
        }
        // Update cases first
        List<Case> casesToUpdate = casesToUpdateMap.values();
        List<Id> updatedCaseIds = new List<Id>();
        List<String> updateFailures = new List<String>();
        if (!casesToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(casesToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    updatedCaseIds.add(casesToUpdate[i].Id);
                } else {
                    String msg = 'Case ' + casesToUpdate[i].Id + ' - ' + results[i].getErrors();
                    System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: update FAILED for ' + msg);
                    updateFailures.add(msg);
                }
            }
        }
        if (!updateFailures.isEmpty()) {
            try {
                Messaging.SingleEmailMessage alert = new Messaging.SingleEmailMessage();
                alert.setToAddresses(new String[] { 'luigi.fumagalli@trimech.com' });
                alert.setSubject('CaseReminderBatchJob: ' + updateFailures.size() + ' update failure(s)');
                alert.setPlainTextBody(String.join(updateFailures, '\n'));
                alert.setSaveAsActivity(false);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { alert });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: alert email failed: ' + e.getMessage());
            }
        }
        // Only send emails/tasks for successfully updated cases
        List<Messaging.SingleEmailMessage> emailsToSendFinal = new List<Messaging.SingleEmailMessage>();
        List<Messaging.SingleEmailMessage> ownerEmailsToSendFinal = new List<Messaging.SingleEmailMessage>();
        
        for (Id cid : updatedCaseIds) {
            if (emailMap.containsKey(cid)) emailsToSendFinal.add(emailMap.get(cid));
            if (ownerEmailMap.containsKey(cid)) ownerEmailsToSendFinal.add(ownerEmailMap.get(cid));
            
        }
        List<String> sendFailures = new List<String>();
        if (!emailsToSendFinal.isEmpty()) {
            try {
                Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(emailsToSendFinal, false);
                for (Messaging.SendEmailResult r : sendResults) {
                    if (!r.isSuccess()) {
                        String msg = 'reminder email - ' + r.getErrors();
                        System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: send FAILED for ' + msg);
                        sendFailures.add(msg);
                    }
                }
            } catch (EmailException e) {
                System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: Failed to send batch email: ' + e.getMessage());
                sendFailures.add('reminder email batch threw - ' + e.getMessage());
            }
        }
        if (!ownerEmailsToSendFinal.isEmpty()) {
            try {
                Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(ownerEmailsToSendFinal, false);
                for (Messaging.SendEmailResult r : sendResults) {
                    if (!r.isSuccess()) {
                        String msg = 'owner 40h email - ' + r.getErrors();
                        System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: send FAILED for ' + msg);
                        sendFailures.add(msg);
                    }
                }
            } catch (EmailException e) {
                System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: Failed to send owner batch email: ' + e.getMessage());
                sendFailures.add('owner 40h email batch threw - ' + e.getMessage());
            }
        }
        if (!sendFailures.isEmpty()) {
            try {
                Messaging.SingleEmailMessage alert = new Messaging.SingleEmailMessage();
                alert.setToAddresses(new String[] { 'luigi.fumagalli@trimech.com' });
                alert.setSubject('CaseReminderBatchJob: ' + sendFailures.size() + ' email send failure(s)');
                alert.setPlainTextBody(String.join(sendFailures, '\n'));
                alert.setSaveAsActivity(false);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { alert });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CaseReminderBatchJob: send-failure alert email failed: ' + e.getMessage());
            }
        }

    }

    private Messaging.SingleEmailMessage buildOwnerBlockedContactEmail(Case c, User ownerUser, Contact con) {
        if (ownerUser == null || ownerUser.Email == null) {
            return null;
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { ownerUser.Email });
        String acctName = (c.Account != null && c.Account.Name != null) ? c.Account.Name : '';
        String caseNum = (c.CaseNumber != null) ? c.CaseNumber : '';
        String reason = (con != null && con.IsEmailBounced) ? 'their email address is bouncing' : 'they have opted out of email';
        mail.setSubject('Contact Unreachable | Case ' + caseNum + (acctName != '' ? ' Account: ' + acctName : ''));
        String body = 'Hello ' + ownerUser.Name + ',\n\n'
            + 'The 16-hour reminder for Case ' + caseNum + (acctName != '' ? ' (Account: ' + acctName + ')' : '')
            + ' was not sent because ' + reason + '.\n\n'
            + 'Please follow up with the client through another channel (phone, etc.).\n\n'
            + 'Case Link: https://trimech12345.lightning.force.com/lightning/r/Case/' + c.Id + '/view\n\nThank you.';
        mail.setPlainTextBody(body);
        mail.setWhatId(c.Id);
        mail.setSaveAsActivity(true);
        return mail;
    }

    private Messaging.SingleEmailMessage buildOwner40hEmail(Case c, User ownerUser) {
        if (ownerUser == null || ownerUser.Email == null) {
            return null;
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { ownerUser.Email });
        String acctName = (c.Account != null && c.Account.Name != null) ? c.Account.Name : '';
        String caseNum = (c.CaseNumber != null) ? c.CaseNumber : '';
        mail.setSubject('Call Client. | Case ' + caseNum + (acctName != '' ? ' Account: ' + acctName : ''));
        String body = 'Hello ' + ownerUser.Name + ',\n\nA call is now needed to the client regarding Case ' + caseNum + (acctName != '' ? ' (Account: ' + acctName + ')' : '') + ' due to no response to the reminder emails.\n\nCase Link: https://trimech12345.lightning.force.com/lightning/r/Case/' + c.Id + '/view\n\nThank you.';
        mail.setPlainTextBody(body);
        mail.setWhatId(c.Id);
        mail.setSaveAsActivity(true);
        return mail;
    }
    private Messaging.SingleEmailMessage buildReminderEmail(Case c, Integer hours, EmailTemplate template, Contact con) {
        if (template == null) {
            System.debug('CaseReminderBatchJob: No email template available for Case ' + c.Id);
            return null;
        }
        if (con == null || con.Email == null) {
            System.debug('CaseReminderBatchJob: Skipping Case ' + c.Id + ': Contact has no email');
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
        System.debug('CaseReminderBatchJob: Built email for Case ' + c.Id + ' with template ' + template.Id + ' and OWEA ' + (bu == 'Hardware' ? '0D2PZ00000006jl0AA' : '0D2PZ00000006i90AA'));
        return mail;
    }


    public void finish(Database.BatchableContext bc) {
        System.debug('CaseReminderBatchJob completed. Batch Id: ' + bc);
        // Optionally: add custom notification or audit logging here
    }
}