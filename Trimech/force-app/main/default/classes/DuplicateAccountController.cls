public class DuplicateAccountController {
    
    @AuraEnabled
    public static void sendemail(String notes,String recordId, String original, String duplicate){
        system.debug(notes);
        system.debug(recordId);
        system.debug(original);
        system.debug(duplicate);
        List<Account> orignalAcc = (List<Account>)JSON.deserialize(original, List<Account>.class);
        List<Account> duplicaAcc = (List<Account>)JSON.deserialize(duplicate, List<Account>.class);
        List<Account> submitRecords = new List<Account>();
        // Map<String,List<Account>> dupeAccounts = duplicateRecords(recordId);
        
        Set<String> accountIds = new Set<String>();

        for(Account acc : duplicaAcc){
            acc.isSubmitted__c = true;
            acc.Notes__c = notes;
            acc.Master_ClientId__c = recordId;
            submitRecords.add(acc);
            accountIds.add(acc.Id);
        }


        for(Account acc : orignalAcc){
            acc.isSubmitted__c = true;
            acc.Notes__c = notes;
            acc.Merge_ClientIds__c =  String.join(new List<String>(accountIds), ', ');
            submitRecords.add(acc);
        }
        
        
        
        String emailBody = '<p>Click the following link to view the record:</p>';
        for(Account inx : orignalAcc){
            emailBody += '<p> Master Record : <a href="' + URL.getOrgDomainURL().toExternalForm()+'/'+ inx.Id + '">'+inx.Name+'</a></p>';
        }
        for(Account inx : duplicaAcc){
            emailBody += '<p> Merge Record : <a href="' + URL.getOrgDomainURL().toExternalForm()+'/'+ inx.Id + '">'+inx.Name+'</a></p>';
        }
        
        emailBody += '<p>Notes : ' + notes +' </p>';
        emailBody += '<p>Requestor : ' + Userinfo.getName() +' </p>';
        
        // emailBody += '<p><a href="' + recordLink + '">View Record</a></p>';
        
        // Set the HTML body
        //email.setHtmlBody(emailBody);
        
        if(!submitRecords.isEmpty()){
            update submitRecords;
        }
        
        
        sendMail(system.label.Duplicate_Merge_Email_Address, orignalAcc[0].name + ' - Duplicate Account Submitted', emailBody, recordId);
        //sendMail('Yosephkinfu@gmail.com', orignalAcc[0].name + ' - Duplicate Submitted', emailBody);
    }
    
    public static void sendMail(String address, String subject, String body, String relatedToId) {
        // Create an email message object
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {address};
            mail.setToAddresses(toAddresses);
        mail.setSubject(subject);
        mail.setHTMLBody(body);

        if (relatedToId != null) {
            mail.setWhatId(relatedToId);
            mail.setSaveAsActivity(true); 
        }


        /*
            String emailAddressId;
            List<OrgWideEmailAddress> owdList = [SELECT Id FROM OrgWideEmailAddress WHERE Address='noreply@trimech.com'];
            if(owdList.size()>0 ){
                emailAddressId = owdList[0].Id;
                mail.setOrgWideEmailAddressId(emailAddressId);
            } 
        */


        // Pass this email message to the built-in sendEmail method 
        // of the Messaging class
        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { mail });
        // Call a helper method to inspect the returned results
        inspectResults(results);
    }
    // Helper method
    public static Boolean inspectResults(Messaging.SendEmailResult[] results) {
        Boolean sendResult = true;
        // sendEmail returns an array of result objects.
        // Iterate through the list to inspect results. 
        // In this class, the methods send only one email, 
        // so we should have only one result.
        for (Messaging.SendEmailResult res : results) {
            if (res.isSuccess()) {
                System.debug('Email sent successfully');
            }
            else {
                sendResult = false;
                System.debug('The following errors occurred: ' + res.getErrors());                 
            }
        }
        return sendResult;
    }
    
    @AuraEnabled
    public static Map<String,List<Account>> duplicateRecords(String recordId){
        
        Map<String,List<Account>> duplicateDetails = new Map<String,List<Account>>();
        
        List<Account> accList = [SELECT id,Notes__c, Name, BillingStreet, BillingCity, BillingState,BillingCountry,BillingPostalCode,Phone,Website 
                                 FROM Account where id = :recordId];
        
        List<Datacloud.FindDuplicatesResult > findDuplicatesResult = Datacloud.FindDuplicates.findDuplicates(accList);
        
        Datacloud.DuplicateResult duplicateResult = findDuplicatesResult.get(0).getDuplicateResults().get(0);
        Datacloud.MatchResult matchResult = duplicateResult.getMatchResults()[0];
        List<Datacloud.MatchRecord> matchRecords = matchResult.getMatchRecords();
        
        List<String> duplicates = new List<String>();
        for(Datacloud.MatchRecord matchRecord : matchRecords){
            SObject duplicate = matchRecord.getRecord();
            System.debug('Match Record: ' + duplicate);
            duplicates.add(String.valueof(duplicate.get('Id')));
        }
        
        List<Account> dupeaccList = new List<Account>([SELECT id,Notes__c, Name, BillingStreet, BillingCity, BillingState,BillingCountry,BillingPostalCode,Phone,Website 
                                                       FROM Account where id in :duplicates]);
        
        duplicateDetails.put('Original',accList);
        duplicateDetails.put('Duplicate',dupeaccList);
        
        
        return duplicateDetails;
    }
}