public with sharing class BridgeITOrderEventHandler {
    public static void HandleOrderUpsert(List<Order> newContactList, List<Order> oldContactList, String triggerType) {

        String url = System.label.BridgeIT_Webhook_Order_Logic_App_Url;
        String content = BridgeITWebhook.jsonContent(newContactList, oldContactList);
        BridgeITWebhook.callout(url, content, triggerType);
    }
}