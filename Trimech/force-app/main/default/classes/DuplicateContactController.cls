public class DuplicateContactController {

    @AuraEnabled
    public static void sendemail(String notes,String recordId, String original, String duplicate){
        system.debug(notes);
        system.debug(recordId);
        system.debug(original);
        system.debug(duplicate);
        List<Contact> orignalAcc = (List<Contact>)JSON.deserialize(original, List<Contact>.class);
        List<Contact> duplicaAcc = (List<Contact>)JSON.deserialize(duplicate, List<Contact>.class);
        List<Contact> submitRecords = new List<Contact>();
        // Map<String,List<Contact>> dupeContacts = duplicateRecords(recordId);
        
        for(Contact acc : orignalAcc){
            acc.isSubmitted__c = true;
            acc.Notes__c = notes;
            submitRecords.add(acc);
        }
        
        for(Contact acc : duplicaAcc){
            acc.isSubmitted__c = true;
            acc.Notes__c = notes;
            submitRecords.add(acc);
        }
        
        
        String emailBody = '<p>Click the following link to view the record:</p>';
        for(Contact inx : orignalAcc){
            emailBody += '<p> Master Record : <a href="' + URL.getOrgDomainURL().toExternalForm()+'/'+ inx.Id + '">'+inx.Name+'</a></p>';
        }
        for(Contact inx : duplicaAcc){
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
        
        
        sendMail(system.label.Duplicate_Merge_Email_Address, orignalAcc[0].name + ' - Duplicate Contact Submitted', emailBody);
        //sendMail('Yosephkinfu@gmail.com', orignalAcc[0].name + ' - Duplicate Submitted', emailBody);
    }
    
    public static void sendMail(String address, String subject, String body) {
        // Create an email message object
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {address};
            mail.setToAddresses(toAddresses);
        mail.setSubject(subject);
        mail.setHTMLBody(body);
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
    public static Map<String,List<Contact>> duplicateRecords(String recordId){
        
        Map<String,List<Contact>> duplicateDetails = new Map<String,List<Contact>>();
        
        List<Contact> accList = [SELECT Id, AccountId, LastName, FirstName, Salutation, MiddleName, Suffix, Name, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude, MailingGeocodeAccuracy, MailingAddress, Phone, Fax, MobilePhone, OtherPhone, ReportsToId, Email, Title, Department, LeadSource, Description, CurrencyIsoCode, OwnerId, HasOptedOutOfEmail, DoNotCall, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastActivityDate, LastCURequestDate, LastCUUpdateDate, LastViewedDate, LastReferencedDate, EmailBouncedReason, EmailBouncedDate, IsEmailBounced, PhotoUrl, Jigsaw, JigsawContactId, IndividualId, IsPriorityRecord, ContactSource, Inactive__c, LinkedIn__c, NetSuite_Id__c, celigo_sfnsio__NetSuite_Id__c, celigo_sfnsio__NetSuite_Record__c, celigo_sfnsio__NetSuite_Sync_Error__c, celigo_sfnsio__Skip_Export_To_NetSuite__c, celigo_sfnsio__Test_Mode_Record__c, Contact_Type__c, Goes_By__c, Account_NetSuite_Id_IO__c, Last_Activity_Date__c, Subsidiary__c, Office_Phone__c, DOZISF__ZoomInfo_Company_ID__c, DOZISF__ZoomInfo_First_Updated__c, CEDAR_Id__c, Cedar_Not_Synced_from_NetSuite__c, DOZISF__ZoomInfo_Id__c, DOZISF__ZoomInfo_Last_Updated__c, pi__Needs_Score_Synced__c, pi__Pardot_Last_Scored_At__c, pi__campaign__c, pi__comments__c, General_Comments__c, pi__conversion_date__c, pi__conversion_object_name__c, pi__conversion_object_type__c, pi__created_date__c, Solidworks_Contact_Id__c, DB_SIC_Code__c, DB_Industry__c, pi__first_activity__c, pi__first_search_term__c, pi__first_search_type__c, Job_Level__c, pi__first_touch_url__c, pi__grade__c, pi__last_activity__c, pi__notes__c, pi__pardot_hard_bounced__c, pi__score__c, pi__url__c, pi__utm_campaign__c, pi__utm_content__c, pi__utm_medium__c, pi__utm_source__c, pi__utm_term__c, External_ID__c, IsMigrated__c, Lead_Product_Category__c, Lead_Product_of_Interest__c, Campaign_Type__c, Training_Course_Name__c, Training_Course_Location__c, Training_Course_Date__c, Last_Registered_Event__c, Pardot_Data_Import__c, LSC_Campaign__c, Submission_Count__c, Last_Attended_Trade_Show__c, Import_Date_Time__c, MQL_SQL__c, UQL_Count__c, GCLID_Google_Click_Identification__c, X6Sense_Segment_Name__c, Pardot_Lightning_URL__c, Task_Import_Date_Time__c, Task_Owner__c, Task_Subject__c, Task_Due_Date__c, isSubmitted__c, Notes__c FROM Contact where id = :recordId];
        
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
        
        List<Contact> dupeaccList = new List<Contact>([SELECT Id, AccountId, LastName, FirstName, Salutation, MiddleName, Suffix, Name, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude, MailingGeocodeAccuracy, MailingAddress, Phone, Fax, MobilePhone, OtherPhone, ReportsToId, Email, Title, Department, LeadSource, Description, CurrencyIsoCode, OwnerId, HasOptedOutOfEmail, DoNotCall, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastActivityDate, LastCURequestDate, LastCUUpdateDate, LastViewedDate, LastReferencedDate, EmailBouncedReason, EmailBouncedDate, IsEmailBounced, PhotoUrl, Jigsaw, JigsawContactId, IndividualId, IsPriorityRecord, ContactSource, Inactive__c, LinkedIn__c, NetSuite_Id__c, celigo_sfnsio__NetSuite_Id__c, celigo_sfnsio__NetSuite_Record__c, celigo_sfnsio__NetSuite_Sync_Error__c, celigo_sfnsio__Skip_Export_To_NetSuite__c, celigo_sfnsio__Test_Mode_Record__c, Contact_Type__c, Goes_By__c, Account_NetSuite_Id_IO__c, Last_Activity_Date__c, Subsidiary__c, Office_Phone__c, DOZISF__ZoomInfo_Company_ID__c, DOZISF__ZoomInfo_First_Updated__c, CEDAR_Id__c, Cedar_Not_Synced_from_NetSuite__c, DOZISF__ZoomInfo_Id__c, DOZISF__ZoomInfo_Last_Updated__c, pi__Needs_Score_Synced__c, pi__Pardot_Last_Scored_At__c, pi__campaign__c, pi__comments__c, General_Comments__c, pi__conversion_date__c, pi__conversion_object_name__c, pi__conversion_object_type__c, pi__created_date__c, Solidworks_Contact_Id__c, DB_SIC_Code__c, DB_Industry__c, pi__first_activity__c, pi__first_search_term__c, pi__first_search_type__c, Job_Level__c, pi__first_touch_url__c, pi__grade__c, pi__last_activity__c, pi__notes__c, pi__pardot_hard_bounced__c, pi__score__c, pi__url__c, pi__utm_campaign__c, pi__utm_content__c, pi__utm_medium__c, pi__utm_source__c, pi__utm_term__c, External_ID__c, IsMigrated__c, Lead_Product_Category__c, Lead_Product_of_Interest__c, Campaign_Type__c, Training_Course_Name__c, Training_Course_Location__c, Training_Course_Date__c, Last_Registered_Event__c, Pardot_Data_Import__c, LSC_Campaign__c, Submission_Count__c, Last_Attended_Trade_Show__c, Import_Date_Time__c, MQL_SQL__c, UQL_Count__c, GCLID_Google_Click_Identification__c, X6Sense_Segment_Name__c, Pardot_Lightning_URL__c, Task_Import_Date_Time__c, Task_Owner__c, Task_Subject__c, Task_Due_Date__c, isSubmitted__c, Notes__c FROM Contact where id in :duplicates]);
        
        duplicateDetails.put('Original',accList);
        duplicateDetails.put('Duplicate',dupeaccList);
        
        
        return duplicateDetails;
    }

}