trigger BridgeITAccountTrigger on Account (after insert, after update) {
    /*if (Trigger.isUpdate) {
        Account newAcc = Trigger.new[0];
        Account oldAcc = Trigger.old[0];

        if (newAcc.celigo_sfnsio__Skip_Export_To_NetSuite__c == true || oldAcc.celigo_sfnsio__Skip_Export_To_NetSuite__c == true) {
            return;
        }

        Set<String> insignificantFields = new Set<String>{
            'LastModifiedDate',
            'SystemModstamp',
            'LastModifiedById',
            'CreatedById',
            'CreatedDate',
            'Account_Id_18__c',
            'Upper_Case_Name__c',
            'Account_Updated__c'
        };

        if (!AccountChangeDetector.hasSignificantChanges(oldAcc, newAcc, insignificantFields)) {
            return; // Skip webhook if nothing important changed
        }
    }

    String contextType = Trigger.isInsert ? 'create' : 'update';
    String url = 'https://prod-31.eastus.logic.azure.com:443/workflows/8096c3b932b041a7b2a26e171e4d94cf/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=4mJm27LVTzPVKdic8nYDCs9l79DCwrKJHs9x2MQHdZc';
    String content = BridgeITWebhook.jsonContent(Trigger.new, Trigger.old);
    BridgeITWebhook.callout(url, content, contextType);*/
}