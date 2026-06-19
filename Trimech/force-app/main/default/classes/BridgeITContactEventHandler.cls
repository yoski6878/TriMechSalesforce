public with sharing class BridgeITContactEventHandler {
    public static void HandleContactUpsert(List<Contact> newContactList, List<Contact> oldContactList, String triggerType) {
        
        // Collect AccountIds from incoming contacts
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : newContactList) if (c.AccountId != null) accountIds.add(c.AccountId);
        if (accountIds.isEmpty()) return;

        // Load Accounts and require a NetSuite Id
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, celigo_sfnsio__NetSuite_Id__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        // Build "new" contacts as plain maps, enriched with AccountNetSuiteId
        List<Map<String, Object>> newContactsCreate = new List<Map<String, Object>>();
        List<Map<String, Object>> newContactsUpdate = new List<Map<String, Object>>();
        Set<Id> eligibleIds = new Set<Id>();

        for (Contact c : newContactList) {
            Account a = (c.AccountId == null) ? null : accountsById.get(c.AccountId);
            if (a != null && !String.isBlank(a.celigo_sfnsio__NetSuite_Id__c)) {
                Map<String, Object> cMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(c));
                cMap.put('AccountNetSuiteId', a.celigo_sfnsio__NetSuite_Id__c); // <-- add to the contact object
                if(String.isBlank(c.celigo_sfnsio__NetSuite_Id__c)) {
                    newContactsCreate.add(cMap);
                }
                else {
                    newContactsUpdate.add(cMap);
                }
                
                eligibleIds.add(c.Id);
            }
        }
        if (newContactsCreate.isEmpty() && newContactsUpdate.isEmpty()) return;

        // Build "old" contacts aligned to eligible ones, also enriched
        List<Map<String, Object>> oldContactsCreate = new List<Map<String, Object>>();
        List<Map<String, Object>> oldContactsUpdate = new List<Map<String, Object>>();
        if (oldContactList != null && !oldContactList.isEmpty()) {
            for (Contact oc : oldContactList) {
                if (!eligibleIds.contains(oc.Id)) continue;
                Account a = (oc.AccountId == null) ? null : accountsById.get(oc.AccountId);
                String nsId = (a != null) ? a.celigo_sfnsio__NetSuite_Id__c : null;

                Map<String, Object> oMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(oc));
                oMap.put('AccountNetSuiteId', nsId); // <-- add to the contact object
                if(String.isBlank(oc.celigo_sfnsio__NetSuite_Id__c)) {
                    oldContactsCreate.add(oMap);
                }
                else {
                    oldContactsUpdate.add(oMap);
                }
            }
        }

        // Send payload where each contact includes AccountNetSuiteId directly
        String url = System.label.BridgeIT_Webhook_Contact_Logic_App_Url;
        if(!newContactsCreate.isEmpty())
        {
            String content = JSON.serialize(new Map<String, Object>{
            'new' => newContactsCreate,
            'old' => oldContactsCreate
            });
            BridgeITWebhook.callout(url, content, 'create');
        }

        if(!newContactsUpdate.isEmpty())
        {
            String content = JSON.serialize(new Map<String, Object>{
            'new' => newContactsUpdate,
            'old' => oldContactsUpdate
            });
            BridgeITWebhook.callout(url, content, 'edit');
        }
    }
}