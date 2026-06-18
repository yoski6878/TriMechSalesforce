public class WeeklyNeglectedReminderBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private Map<Id, List<Opportunity>> ownerToOpps = new Map<Id, List<Opportunity>>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, Account.Name, ProductGroup_Name__c
            FROM Opportunity
            WHERE RecordType.DeveloperName = 'Lead'
              AND StageName = 'Neglected'
              AND IsClosed = false
              AND CreatedDate >= 2026-01-01T00:00:00Z
              AND ProductGroup_Name__c IN ('Hardware','AMS','Software','Staffing','Product Development','SSG-CRE','CPQ','Aras','SSG-BT','SolidCAM')
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        for (Opportunity opp : scope) {
            if (!ownerToOpps.containsKey(opp.OwnerId)) {
                ownerToOpps.put(opp.OwnerId, new List<Opportunity>());
            }
            ownerToOpps.get(opp.OwnerId).add(opp);
        }
    }
    
    public void finish(Database.BatchableContext bc) {

        OrgWideEmailAddress owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE Address = 'noreply@trimech.com'
            LIMIT 1
        ];

        Map<Id, User> ownerById = new Map<Id, User>([
            SELECT Id, Email, IsActive
            FROM User
            WHERE Id IN :ownerToOpps.keySet()
        ]);

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id ownerId : ownerToOpps.keySet()) {
            User owner = ownerById.get(ownerId);
            if (owner == null || !owner.IsActive) {
                continue;
            }
            String csvHeader = csvField('Id') + ',' + csvField('Link') + ',' + csvField('Name') + ',' + csvField('AccountName') + '\n';
            String csvBody = '';
            for (Opportunity o : ownerToOpps.get(ownerId)) {
                String link = baseUrl + '/' + o.Id;
                String acctName = (o.Account != null ? o.Account.Name : '');
                csvBody += csvField(o.Id) + ',' + csvField(link) + ',' + csvField(o.Name) + ',' + csvField(acctName) + '\n';
            }
            String csvContent = csvHeader + csvBody;
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('NeglectedLeads.csv');
            attachment.setBody(Blob.valueOf(csvContent));
            attachment.setContentType('text/csv');
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { owner.Email });
            mail.setOrgWideEmailAddressId(owea.Id);
            mail.setSubject('Weekly Reminder: Neglected Leads');
            mail.setPlainTextBody('Attached is the list of your neglected leads.');
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {attachment});
            emails.add(mail);
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    // Escapes a value for safe CSV output: doubles embedded quotes and prefixes
    // formula-trigger characters with a single quote to prevent injection in Excel/Sheets.
    private static String csvField(String value) {
        if (value == null) {
            return '""';
        }
        String safe = value;
        if (safe.startsWith('=') || safe.startsWith('+') || safe.startsWith('-') || safe.startsWith('@')) {
            safe = '\'' + safe;
        }
        return '"' + safe.replace('"', '""') + '"';
    }
}