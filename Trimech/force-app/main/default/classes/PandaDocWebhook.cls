/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PandaDocWebhook
 * Author          : <YourName>
 * Created Date    : Apr 29, 2026
 * Last Modified By: <YourName>
 * Last Modified On: May 14, 2026
 * Description     : REST endpoint receiving PandaDoc webhook events.
 *                   On document_state_changed — updates Status__c.
 *                   On document.completed — also sets Fetch_Status__c = Pending
 *                   so PandaDocAttachBatch picks it up in the next run.
 *                   PDF attachment is fully handled by PandaDocAttachBatch.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 29, 2026  │ <YourName>   │ Initial version
 *  May 14, 2026  │ <YourName>   │ Replaced upsert with insert/update split
 *                │              │ Status update only — no PDF logic
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@RestResource(urlMapping='/pandadoc/*')
global without sharing class PandaDocWebhook {

    @HttpPost
    global static void handleWebhook() {

        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String       requestBody = req.requestBody.toString();
            List<Object> events      = (List<Object>) JSON.deserializeUntyped(requestBody);

            System.debug('PandaDocWebhook payload: ' + JSON.serializePretty(events));

            Map<String, String> docIdToStatus = new Map<String, String>();

            for (Object eventObj : events) {
                Map<String, Object> event     = (Map<String, Object>) eventObj;
                String              eventType = (String) event.get('event');

                if (eventType != 'document_state_changed') continue;

                Map<String, Object> data       = (Map<String, Object>) event.get('data');
                String              status     = (String) data.get('status');
                String              documentId = (String) data.get('id');

                if (String.isBlank(status) || String.isBlank(documentId)) continue;

                System.debug('PandaDocWebhook documentId=' + documentId + ' status=' + status);
                docIdToStatus.put(documentId, status);
            }

            if (!docIdToStatus.isEmpty()) {
                persistStatusChanges(docIdToStatus);
            }

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf('Success');

        } catch (Exception e) {
            System.debug('PandaDocWebhook Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }

    private static void persistStatusChanges(Map<String, String> docIdToStatus) {

        Map<String, Panda_Docs_Document__c> existing = new Map<String, Panda_Docs_Document__c>();
        for (Panda_Docs_Document__c rec : [
            SELECT Id, DocumentId__c, Status__c, Fetch_Status__c
            FROM   Panda_Docs_Document__c
            WHERE  DocumentId__c IN :docIdToStatus.keySet()
        ]) {
            existing.put(rec.DocumentId__c, rec);
        }

        List<Panda_Docs_Document__c> toInsert = new List<Panda_Docs_Document__c>();
        List<Panda_Docs_Document__c> toUpdate = new List<Panda_Docs_Document__c>();

        for (String docId : docIdToStatus.keySet()) {
            String pandaStatus = docIdToStatus.get(docId);
            Boolean isCompleted = pandaStatus == 'document.completed';

            if (existing.containsKey(docId)) {
                Panda_Docs_Document__c rec = existing.get(docId);
                rec.Status__c = pandaStatus;
                // When completed, reset Fetch_Status to Pending
                // so the batch picks it up on the next run
                if (isCompleted) {
                    rec.Fetch_Status__c      = 'Pending';
                    rec.Fetch_Retry_Count__c = 0;
                    rec.PDF_Attached__c      = false;
                }
                toUpdate.add(rec);
            } else {
                toInsert.add(new Panda_Docs_Document__c(
                    DocumentId__c        = docId,
                    Status__c            = pandaStatus,
                    PDF_Attached__c      = false,
                    Fetch_Retry_Count__c = 0,
                    Fetch_Status__c      = isCompleted ? 'Pending' : null
                ));
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;

        System.debug('PandaDocWebhook inserted=' + toInsert.size() + ' updated=' + toUpdate.size());
    }
}