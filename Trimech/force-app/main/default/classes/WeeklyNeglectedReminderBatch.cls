public class WeeklyNeglectedReminderBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private Map<Id, List<Opportunity>> ownerToOpps = new Map<Id, List<Opportunity>>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, Account.Name, ProductGroup_Name__c
            FROM Opportunity 
            WHERE RecordType.DeveloperName = 'Lead'
              AND StageName = 'Neglected'
              AND ProductGroup_Name__c IN ('Hardware','AMS')
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


        for (Id ownerId : ownerToOpps.keySet()) {
            
            String csvHeader = 'Id,Link,Name,AccountName\n';
            String csvBody = '';
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            for (Opportunity o : ownerToOpps.get(ownerId)) {
				String link = baseUrl + '/' + o.Id;
                String acctName = (o.Account != null ? o.Account.Name : '');
                csvBody += '"' + o.Id + '","' + link + '","' + o.Name + '","' + acctName + '"\n';
            }
            
            String csvContent = csvHeader + csvBody;
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('NeglectedLeads.csv');
            attachment.setBody(Blob.valueOf(csvContent));
            attachment.setContentType('text/csv');
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(ownerId);
            mail.setOrgWideEmailAddressId(owea.Id);
            mail.setSaveAsActivity(false);
            mail.setSubject('Weekly Reminder: Neglected Leads');
            mail.setPlainTextBody('Attached is the list of your neglected leads.');
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {attachment});
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        }
    }
}