global class AcctTerrAssignBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, Name, Software_Sales_Person__c, Enterprise_Sales_Person__c, Hardware_Sales_Person__c, Client_Engagement_Rep__c, SolidCAM_Sales_Person__c, ShippingPostalCode
            FROM Account
            WHERE Type = 'Client' AND ShippingPostalCode != null AND ShippingPostalCode NOT IN ('- None -','0','-')
            AND Primary_Territory__c !=null 
            LIMIT 100
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Account> scope) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : scope) accountIds.add(acc.Id);
        Map<Id, List<Territory_Assignment__c>> acctToAssignments = new Map<Id, List<Territory_Assignment__c>>();
        for (Territory_Assignment__c ta : [SELECT Id, Name, Assigned_User_Id__c, Account_Field_to_Assign__c FROM Territory_Assignment__c WHERE Account_Field_to_Assign__c IN :accountIds]) {
            if (!acctToAssignments.containsKey((Id)ta.Account_Field_to_Assign__c)) acctToAssignments.put((Id)ta.Account_Field_to_Assign__c, new List<Territory_Assignment__c>());
            acctToAssignments.get((Id)ta.Account_Field_to_Assign__c).add(ta);
        }
        for (Account acc : scope) {
            List<Territory_Assignment__c> assignments = acctToAssignments.get(acc.Id);
            if (assignments != null) {
                for (Territory_Assignment__c ta : assignments) {
                    // Example: compare Software_Sales_Person__c to Assigned_User_Id__c
                    System.debug('Account: ' + acc.Id + ' (' + acc.Name + ') | Account.Software_Sales_Person__c: ' + acc.Software_Sales_Person__c + ' | Assignment.Assigned_User_Id__c: ' + ta.Assigned_User_Id__c);
                    if (acc.Software_Sales_Person__c != ta.Assigned_User_Id__c) {
                        System.debug('Mismatch for Account: ' + acc.Id + ' Assignment: ' + ta.Id);
                    }
                }
            }
        }
    }

    global void finish(Database.BatchableContext BC) {}
}