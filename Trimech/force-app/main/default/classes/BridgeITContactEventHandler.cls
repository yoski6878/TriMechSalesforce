public with sharing class BridgeITContactEventHandler {
    public static void HandleContactUpsert(List<Contact> newContactList, List<Contact> oldContactList, String triggerType) {

        String url = 'https://prod-08.eastus.logic.azure.com:443/workflows/4f6b4ca2bcce4418890b5751361cba8b/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=_WFn6rPXKcLp166b7vyDkVEt9KQ9cmNBuCsHePZS-N4';
        String content = BridgeITWebhook.jsonContent(newContactList, oldContactList);
        BridgeITWebhook.callout(url, content, triggerType);
    }
}