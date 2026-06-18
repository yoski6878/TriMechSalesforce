/**
* @File Name : BatchToNotifyForInactiveOLI.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 28, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 28, 2025 |   | Initial Version
**/

global class BatchToNotifyForInactiveOLI implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    private Map<String, Set<String>> ownerToOliDetails = new Map<String, Set<String>>();

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
                        'SELECT Id, Name, Owner.Email, ' +
            '(SELECT Id, Name, Product2.ProductCode FROM OpportunityLineItems WHERE Product2.IsActive = FALSE) ' +
            'FROM Opportunity WHERE Owner.Email != null' +
            'AND IsClosed = FALSE AND Id IN ' +
            '(SELECT OpportunityId FROM OpportunityLineItem WHERE Product2.IsActive = FALSE)'
        );
    }
    
    global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
        
        for (Opportunity opp : scope) {
            if (opp.Owner.Email == null || opp.OpportunityLineItems.isEmpty()) {
                continue;
            }
            
            for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                String oppUrl = baseUrl + '/' + opp.Id;
                String oliUrl = baseUrl + '/' + oli.Id;
                String csvRow = opp.Id + ',' + escapeCsvField(opp.Name) + ',' + oli.Id + ',' + escapeCsvField(oli.Name) + ',' + oli.Product2.ProductCode + ',' + '"=HYPERLINK(""' + oliUrl + '"", ""Open OLI"")"' + ',' + '"=HYPERLINK(""' + oppUrl + '"", ""Open Opportunity"")"';
                
                if (!ownerToOliDetails.containsKey(opp.Owner.Email)) {
                    ownerToOliDetails.put(opp.Owner.Email, new Set<String>());
                }
                ownerToOliDetails.get(opp.Owner.Email).add(csvRow);
            }
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (String ownerEmail : ownerToOliDetails.keySet()) {
            List<String> csvLines = new List<String>();
            csvLines.add('Opportunity ID,Opportunity Name,Opportunity Line Item ID,Opportunity Line Item Name,Product Code,OLI URL,Opportunity URL'); 
            csvLines.addAll(ownerToOliDetails.get(ownerEmail));
            Blob csvBlob = Blob.valueOf(String.join(csvLines, '\n'));

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFilename('Inactive_Opportunity_Line_Items.csv');
            attachment.setBody(csvBlob);
            attachment.setContentType('text/csv');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{ownerEmail});
            email.setSenderDisplayName('Administration');
            email.setReplyTo('NoReply@trimech.com');
            email.setSubject('Inactive Opportunity Line Items Notification');
            email.setPlainTextBody('Hello,\n\nPlease review the attached list of Opportunity Line Items that are inactive. Kindly remove or update the inactive items. If you have any questions, contact the sales operations team through an IT Request ticket.\n\nRegards,\nAdministration');
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});    
            emails.add(email);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    public static String escapeCsvField(String fieldValue) {
    if (fieldValue == null) {
        return '';
    }
    String escapedValue = fieldValue.replace('"', '""');
    if (escapedValue.contains(',') || escapedValue.contains('"') || escapedValue.contains('\n')) {
        escapedValue = '"' + escapedValue + '"';
    }
    return escapedValue;
}


    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new BatchToNotifyForInactiveOLI());
    }
}