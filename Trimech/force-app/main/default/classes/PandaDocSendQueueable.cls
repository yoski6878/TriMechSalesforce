/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PandaDocSendQueueable
 * Author          : <YourName>
 * Created Date    : May 12, 2026
 * Last Modified By: <YourName>
 * Last Modified On: May 14, 2026
 * Description     : Polls PandaDoc until document is in 'document.draft' status
 *                   then sends it. Retries up to MAX_RETRIES times with delay.
 *                   Called from pandaDocsIntegration.createPandaDoc() after
 *                   document is created in PandaDoc.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 12, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class PandaDocSendQueueable implements Queueable, Database.AllowsCallouts {

    private static final String  LOG                   = '[PandaDocSendQueueable] ';
    private static final Integer MAX_RETRIES           = 5;
    private static final Integer INITIAL_DELAY_MINUTES = 2;
    private static final Integer RETRY_DELAY_MINUTES   = 1;
    private static final String  READY_STATUS          = 'document.draft';

    private String  documentId;
    private Integer retryCount;

    public PandaDocSendQueueable(String documentId) {
        this(documentId, 0);
    }

    private PandaDocSendQueueable(String documentId, Integer retryCount) {
        this.documentId  = documentId;
        this.retryCount  = retryCount;
    }

    public void execute(QueueableContext ctx) {

        System.debug(LOG + '========== START ==========');
        System.debug(LOG + 'Document Id : ' + documentId);
        System.debug(LOG + 'Attempt     : ' + (retryCount + 1) + '/' + MAX_RETRIES);

        String currentStatus = getDocumentStatus(documentId);

        if (currentStatus == null) {
            handleNotReady('Status check failed');
            return;
        }

        System.debug(LOG + 'PandaDoc status: ' + currentStatus);

        if (currentStatus == READY_STATUS) {
            if (sendDocument(documentId)) {
                updateStatus(documentId, 'Sent');
                System.debug(LOG + 'Document sent successfully.');
            } else {
                updateStatus(documentId, 'Send Failed');
                System.debug(LOG + 'Send failed.');
            }
        } else if (isTerminal(currentStatus)) {
            System.debug(LOG + 'Terminal status ' + currentStatus + ' — aborting.');
            updateStatus(documentId, 'Send Failed');
        } else {
            handleNotReady('Not ready, status=' + currentStatus);
        }

        System.debug(LOG + '========== END ==========');
    }

    private String getDocumentStatus(String docId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:PandaDoc/public/v1/documents/' + docId);
            req.setMethod('GET');
            HttpResponse res = new Http().send(req);
            System.debug(LOG + 'Status check HTTP ' + res.getStatusCode());
            if (res.getStatusCode() == 200) {
                return (String) ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('status');
            }
            System.debug(LOG + 'Status check error: ' + res.getBody());
        } catch (Exception e) {
            System.debug(LOG + 'Status check exception: ' + e.getMessage());
        }
        return null;
    }

    private Boolean sendDocument(String docId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:PandaDoc/public/v1/documents/' + docId + '/send');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'subject' => 'Please review and sign the document',
                'message' => 'Hi,\n\nPlease review and sign the document.\n\nThanks!',
                'silent'  => false
            }));
            HttpResponse res = new Http().send(req);
            System.debug(LOG + 'Send HTTP ' + res.getStatusCode() + ' | ' + res.getBody());
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug(LOG + 'Send exception: ' + e.getMessage());
            return false;
        }
    }

    private void handleNotReady(String reason) {
        System.debug(LOG + 'Not ready: ' + reason);
        if (retryCount < MAX_RETRIES - 1) {
            System.enqueueJob(new PandaDocSendQueueable(documentId, retryCount + 1), RETRY_DELAY_MINUTES);
        } else {
            System.debug(LOG + 'MAX_RETRIES reached — marking Send Failed.');
            updateStatus(documentId, 'Send Failed');
        }
    }

    private static Boolean isTerminal(String status) {
        return status == 'document.voided'
            || status == 'document.declined'
            || status == 'document.completed'
            || status == 'document.sent';
    }

    private static void updateStatus(String docId, String newStatus) {
        try {
            List<Panda_Docs_Document__c> recs = [
                SELECT Id, Status__c FROM Panda_Docs_Document__c
                WHERE DocumentId__c = :docId LIMIT 1
            ];
            if (!recs.isEmpty()) {
                recs[0].Status__c = newStatus;
                update recs[0];
            }
        } catch (Exception e) {
            System.debug(LOG + 'updateStatus failed: ' + e.getMessage());
        }
    }
}