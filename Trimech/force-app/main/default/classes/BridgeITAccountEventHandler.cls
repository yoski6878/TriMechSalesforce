public with sharing class BridgeITAccountEventHandler {
    public static void HandleAccountUpsert(List<Account> newAccountList, List<Account> oldAccountList, String triggerType) {
        if (newAccountList == null || newAccountList.isEmpty()) {
            return;
        }

        List<Account> filteredNewAccounts = new List<Account>();
        List<Account> filteredOldAccounts = new List<Account>();

        Set<String> insignificantFields = new Set<String>{
            'LastModifiedDate',
            'SystemModstamp',
            'LastModifiedById',
            'CreatedById',
            'CreatedDate',
            'Account_Id_18__c',
            'Upper_Case_Name__c',
            'Account_Updated__c',
            'celigo_sfnsio__Skip_Export_To_NetSuite__c',
            'celigo_sfnsio__NetSuite_Id__c',
            'Subsidiary__c'
        };

        for (Integer i = 0; i < newAccountList.size(); i++) {
            Account newAcc = newAccountList[i];
            Account oldAcc = (triggerType == 'edit' && oldAccountList != null && oldAccountList.size() > i)
                ? oldAccountList[i]
                : null;

            Boolean skipNew = Boolean.valueOf(newAcc.celigo_sfnsio__Skip_Export_To_NetSuite__c);
            Boolean skipOld = (oldAcc != null) ? Boolean.valueOf(oldAcc.celigo_sfnsio__Skip_Export_To_NetSuite__c) : false;

            Boolean hasMeaningfulChange;
            if (triggerType == 'edit') {
                hasMeaningfulChange = (oldAcc != null)
                    ? AccountChangeDetector.hasSignificantChanges(oldAcc, newAcc, insignificantFields)
                    : false; // ← treat as NOT meaningful if we can't compare
            } else {
                hasMeaningfulChange = true; // e.g. create
            }

            // 👇 Improved logic
            if ((triggerType == 'edit' && (skipNew || skipOld) && !hasMeaningfulChange) ||
                (triggerType == 'create' && skipNew)) {
                System.debug('Skipping account due to skip export flag.');
                continue;
            }


            filteredNewAccounts.add(newAcc);
            filteredOldAccounts.add(oldAcc);
        }

        if (filteredNewAccounts.isEmpty()) {
            return; // No accounts to process
        }

        String url = 'https://prod-31.eastus.logic.azure.com:443/workflows/8096c3b932b041a7b2a26e171e4d94cf/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=4mJm27LVTzPVKdic8nYDCs9l79DCwrKJHs9x2MQHdZc';
        String content = BridgeITWebhook.jsonContent(filteredNewAccounts, filteredOldAccounts);
        BridgeITWebhook.callout(url, content, triggerType);
    }
}