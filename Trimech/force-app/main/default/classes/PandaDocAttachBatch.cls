/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PandaDocAttachBatch
 * Author          : <YourName>
 * Created Date    : May 14, 2026
 * Description     : Batch class that runs every 15 minutes via
 *                   PandaDocAttachScheduler. Finds all Panda_Docs_Document__c
 *                   records where the document is completed but PDF is not yet
 *                   attached, downloads the signed PDF from PandaDoc and attaches
 *                   it to Panda Doc record, Opportunity, Primary Contact, Account.
 *
 *                   TRACKING FIELDS ON Panda_Docs_Document__c:
 *                   ┌─────────────────────────┬───────────┬──────────────────────────────────┐
 *                   │ Field                   │ Type      │ Purpose                          │
 *                   ├─────────────────────────┼───────────┼──────────────────────────────────┤
 *                   │ PDF_Attached__c          │ Checkbox  │ True when PDF attached OK        │
 *                   │ Fetch_Retry_Count__c     │ Number    │ Attempts made — max 5            │
 *                   │ Fetch_Error__c           │ Long Text │ Last error message               │
 *                   │ Fetch_Status__c          │ Picklist  │ Pending/In Progress/Done/Failed  │
 *                   └─────────────────────────┴───────────┴──────────────────────────────────┘
 *
 *                   CREATE THESE FIELDS ON Panda_Docs_Document__c BEFORE DEPLOYING:
 *                   1. PDF_Attached__c        — Checkbox,       default false
 *                   2. Fetch_Retry_Count__c   — Number(3,0),    default 0
 *                   3. Fetch_Error__c         — Long Text Area,  length 32768
 *                   4. Fetch_Status__c        — Picklist values:
 *                                               Pending, In Progress, Completed, Failed
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 14, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class PandaDocAttachBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private static final String  LOG          = '[PandaDocAttachBatch] ';
    private static final Integer MAX_RETRIES  = 5;

    // Holds the reason for the last download failure so it can be
    // written to Fetch_Error__c with full PandaDoc error detail
    private String lastDownloadError;

    // ── Start — query scope ───────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug(LOG + '========== BATCH START ==========');
        System.debug(LOG + 'Running As : ' + UserInfo.getUserName() + ' (' + UserInfo.getUserId() + ')');

        // Local variable required: Database.getQueryLocator() cannot bind to
        // static class-level variables — Salesforce fails with "tmpVar1 does not exist".
        Integer maxRetries = MAX_RETRIES;

        return Database.getQueryLocator([
            SELECT Id, Name, DocumentId__c, Status__c,
                   Lead_Opportunity__c,
                   Lead_Opportunity__r.Primary_Contact__c,
                   Lead_Opportunity__r.AccountId,
                   PDF_Attached__c,
                   Fetch_Retry_Count__c,
                   Fetch_Error__c,
                   Fetch_Status__c
            FROM   Panda_Docs_Document__c
            WHERE  Status__c            = 'document.completed'
            AND    PDF_Attached__c      = false
            AND    Fetch_Retry_Count__c < :maxRetries
        ]);
    }

    // ── Execute — process each batch of records ───────────────────────────────────
    public void execute(Database.BatchableContext bc, List<Panda_Docs_Document__c> scope) {

        System.debug(LOG + 'Processing batch of ' + scope.size() + ' records.');

        List<Panda_Docs_Document__c> toUpdate = new List<Panda_Docs_Document__c>();

        for (Panda_Docs_Document__c rec : scope) {

            System.debug(LOG + '--- Processing: ' + rec.Name + ' DocumentId=' + rec.DocumentId__c);
            System.debug(LOG + '    Attempt ' + (Integer)(rec.Fetch_Retry_Count__c + 1) + '/' + MAX_RETRIES);

            // Mark In Progress
            rec.Fetch_Status__c      = 'In Progress';
            rec.Fetch_Retry_Count__c = rec.Fetch_Retry_Count__c + 1;

            // ── Download PDF ──────────────────────────────────────────────────────
            lastDownloadError = null; // reset before each attempt
            Blob pdfBlob = downloadDocument(rec.DocumentId__c);

            if (pdfBlob == null) {
                // Download failed — write the actual PandaDoc error reason to Fetch_Error__c
                String errorMsg = 'Attempt ' + (Integer)rec.Fetch_Retry_Count__c
                                + ' failed — ' + (String.isNotBlank(lastDownloadError)
                                    ? lastDownloadError
                                    : 'Unknown error — check debug log');
                rec.Fetch_Error__c  = errorMsg;
                rec.Fetch_Status__c = rec.Fetch_Retry_Count__c >= MAX_RETRIES ? 'Failed' : 'Pending';
                System.debug(LOG + '    FAILED — Fetch_Error__c set to: ' + errorMsg);
                lastDownloadError = null; // reset for next record
                toUpdate.add(rec);
                continue;
            }

            System.debug(LOG + '    Downloaded ' + pdfBlob.size() + ' bytes.');

            // ── Insert ContentVersion ─────────────────────────────────────────────
            ContentVersion cv = new ContentVersion(
                Title        = rec.Name,
                PathOnClient = rec.Name + '.pdf',
                VersionData  = pdfBlob
            );

            try {
                insert cv;
                System.debug(LOG + '    ContentVersion inserted: ' + cv.Id);
            } catch (Exception e) {
                rec.Fetch_Error__c  = 'ContentVersion insert failed: ' + e.getMessage();
                rec.Fetch_Status__c = rec.Fetch_Retry_Count__c >= MAX_RETRIES ? 'Failed' : 'Pending';
                System.debug(LOG + '    ContentVersion FAILED: ' + e.getMessage());
                toUpdate.add(rec);
                continue;
            }

            Id contentDocId;
            try {
                contentDocId = [
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
                ].ContentDocumentId;
            } catch (Exception e) {
                rec.Fetch_Error__c  = 'ContentDocumentId lookup failed: ' + e.getMessage();
                rec.Fetch_Status__c = rec.Fetch_Retry_Count__c >= MAX_RETRIES ? 'Failed' : 'Pending';
                toUpdate.add(rec);
                continue;
            }

            // ── Insert ContentDocumentLinks ───────────────────────────────────────
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();

            System.debug(LOG + '    Linking to Panda Doc record : ' + rec.Id);
            links.add(makeLink(contentDocId, rec.Id));

            if (rec.Lead_Opportunity__c != null) {
                System.debug(LOG + '    Linking to Opportunity       : ' + rec.Lead_Opportunity__c);
                links.add(makeLink(contentDocId, rec.Lead_Opportunity__c));
            } else {
                System.debug(LOG + '    SKIPPED Opportunity — null.');
            }

            if (rec.Lead_Opportunity__r.Primary_Contact__c != null) {
                System.debug(LOG + '    Linking to Contact           : ' + rec.Lead_Opportunity__r.Primary_Contact__c);
                links.add(makeLink(contentDocId, rec.Lead_Opportunity__r.Primary_Contact__c));
            } else {
                System.debug(LOG + '    SKIPPED Contact — null.');
            }

            if (rec.Lead_Opportunity__r.AccountId != null) {
                System.debug(LOG + '    Linking to Account           : ' + rec.Lead_Opportunity__r.AccountId);
                links.add(makeLink(contentDocId, rec.Lead_Opportunity__r.AccountId));
            } else {
                System.debug(LOG + '    SKIPPED Account — null.');
            }

            try {
                insert links;
                System.debug(LOG + '    ' + links.size() + ' links inserted.');
            } catch (Exception e) {
                rec.Fetch_Error__c  = 'ContentDocumentLink insert failed: ' + e.getMessage();
                rec.Fetch_Status__c = rec.Fetch_Retry_Count__c >= MAX_RETRIES ? 'Failed' : 'Pending';
                System.debug(LOG + '    Links FAILED: ' + e.getMessage());
                toUpdate.add(rec);
                continue;
            }

            // ── All good — mark as successfully attached ──────────────────────────
            rec.PDF_Attached__c  = true;
            rec.Fetch_Status__c  = 'Completed';
            rec.Fetch_Error__c   = null;
            System.debug(LOG + '    SUCCESS — PDF attached to ' + links.size() + ' records.');

            toUpdate.add(rec);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug(LOG + 'Updated ' + toUpdate.size() + ' tracking records.');
        }
    }

    // ── Finish ────────────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug(LOG + '========== BATCH COMPLETE ==========');

        Integer maxRetries = MAX_RETRIES;
        Integer failedCount = [
            SELECT COUNT() FROM Panda_Docs_Document__c
            WHERE  PDF_Attached__c      = false
            AND    Fetch_Retry_Count__c >= :maxRetries
            AND    Status__c            = 'document.completed'
        ];

        if (failedCount > 0) {
            System.debug(LOG + 'WARNING — ' + failedCount
                         + ' records have exhausted all ' + MAX_RETRIES
                         + ' retries and Fetch_Status__c = Failed.');
            System.debug(LOG + 'ACTION REQUIRED — Review Fetch_Error__c on those records.');
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────────

    private Blob downloadDocument(String docId) {
        try {
            System.debug(LOG + '    Calling PandaDoc download endpoint for DocumentId=' + docId);
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:PandaDoc/public/v1/documents/' + docId + '/download');
            req.setMethod('GET');
            req.setTimeout(120000); // 120 seconds — PandaDoc PDF generation can be slow

            HttpResponse res = new Http().send(req);

            System.debug(LOG + '    Download HTTP Status   : ' + res.getStatusCode() + ' ' + res.getStatus());
            System.debug(LOG + '    Download Response Size : ' + res.getBodyAsBlob()?.size() + ' bytes');

            if (res.getStatusCode() == 200) {
                System.debug(LOG + '    Download SUCCESS.');
                return res.getBodyAsBlob();
            }

            // Non-200 — log full response body so Fetch_Error__c has the real reason
            String errorBody = res.getBody();
            System.debug(LOG + '    Download FAILED — HTTP ' + res.getStatusCode());
            System.debug(LOG + '    PandaDoc Error Response: ' + errorBody);
            lastDownloadError = 'HTTP ' + res.getStatusCode() + ' — ' + errorBody;

        } catch (Exception e) {
            System.debug(LOG + '    Download EXCEPTION: ' + e.getMessage());
            System.debug(LOG + '    Stack Trace: ' + e.getStackTraceString());
            lastDownloadError = 'Exception: ' + e.getMessage();
        }
        return null;
    }

    private static ContentDocumentLink makeLink(Id contentDocId, Id entityId) {
        return new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId    = entityId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
    }
}