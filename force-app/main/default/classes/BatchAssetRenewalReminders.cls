public class BatchAssetRenewalReminders implements Database.Batchable<sObject>, Schedulable {
    
    public void execute(SchedulableContext sc){
        BatchAssetRenewalReminders sch = new BatchAssetRenewalReminders();
        Database.executeBatch(sch);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT AccountId, RecordType.Name, Quantity, UsageEndDate, Account.Software_Sales_Person__c, Account.Hardware_Sales_Person__c 
                                FROM Asset WHERE Quantity != null AND Status = 'Active' AND UsageEndDate = NEXT_N_DAYS:90 
                                ORDER BY AccountId, RecordType.Name]);
    }

    public void execute(Database.BatchableContext BC, List<Asset> scope) {
        Date endDate = Date.today() + 7;
        List<User> allActiveUsers = [SELECT Id, Full_Name__c FROM User WHERE IsActive = true];
        Map<String, String> userIdNameMap = new Map<String, String>();
        for (User u : allActiveUsers) {
            userIdNameMap.put(u.Full_Name__c, u.Id);
        }
        
        Map<String,Task> tasksToInsert = new Map<String,Task>();
        Map<String,String> groupAccountToSalesReps = new Map<String,String>();
        Map<String, String> groupAccountToTaskOwner = new Map<String, String>();
        Map<String,Decimal> groupQuantityToAccount = new Map<String,Decimal>();

        for(Asset a : scope){
            String key = a.AccountId + '|' + a.RecordType.Name;
            Decimal qnt = a.Quantity;
            if(groupQuantityToAccount.containsKey(key)) {
                qnt += groupQuantityToAccount.get(key);
            }
            groupQuantityToAccount.put(key, qnt);

            if(a.RecordType.Name == 'Software') {
                groupAccountToSalesReps.put(key,a.Account.Software_Sales_Person__c);
            }
            else if(a.RecordType.Name == 'Hardware') {
                groupAccountToSalesReps.put(key,a.Account.Hardware_Sales_Person__c);
            }
        }

        for(String key : groupAccountToSalesReps.keySet()){
            String fullName = groupAccountToSalesReps.get(key);
            String uId = userIdNameMap.get(fullName);
            groupAccountToTaskOwner.put(key,uId);
        }

        for(String key : groupQuantityToAccount.keySet()){
            if(!(tasksToInsert.containsKey(key))) {
                if(groupQuantityToAccount.get(key) > 6.0) {
                    String acctId = key.split('\\|')[0];
                    String recordTypeName = key.split('\\|')[1];
                    String taskSubject = recordTypeName  + ' Assets Renewal Reminder';
                    String taskOwnerId = groupAccountToTaskOwner.get(key);
                    String taskUpsertKey = key + '|' + String.valueOf(Date.today());
                    tasksToInsert.put(key,new Task(WhatId = acctId, Subject = taskSubject, ActivityDate = endDate, OwnerId = taskOwnerId, Upsert_Key__c = taskUpsertKey, RecordTypeId = '0124V0000026tMBQAY'));
                }
            }
        }

        if(!(tasksToInsert.isEmpty())) {
            try{
                upsert tasksToInsert.values() Upsert_Key__c;
            }
            catch(Exception e){
                System.debug('Error inserting tasks: ' + e.getMessage());
            }
        }
    }
  
    public void finish(Database.BatchableContext BC){}
}