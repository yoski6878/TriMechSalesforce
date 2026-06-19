/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PandaDocServiceQueueable
 * Author          : <YourName>
 * Created Date    : May 12, 2026
 * Last Modified By: <YourName>
 * Last Modified On: May 14, 2026
 * Description     : Downloads the signed PDF and attaches it to all related
 *                   records. Enqueued by PandaDocCompletedTrigger which runs
 *                   as the Automated Process user — so ContentVersion DML
 *                   always succeeds regardless of who triggered the webhook.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 12, 2026  │ <YourName>   │ Initial version
 *  May 14, 2026  │ <YourName>   │ Now enqueued from Platform Event trigger
 *                │              │ (Automated Process user) instead of directly
 *                │              │ from webhook (guest user). Solves ContentVersion
 *                │              │ DML block on guest user context.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class PandaDocServiceQueueable implements Queueable, Database.AllowsCallouts {

    private static final String LOG = '[PandaDocServiceQueueable] ';

    private String documentId;

    public PandaDocServiceQueueable(String documentId) {
        this.documentId = documentId;
    }

    public void execute(QueueableContext ctx) {

        System.debug(LOG + '========== START ==========');
        System.debug(LOG + 'Job Id      : ' + ctx.getJobId());
        System.debug(LOG + 'Document Id : ' + documentId);
        System.debug(LOG + 'Running As  : ' + UserInfo.getUserName() + ' (' + UserInfo.getUserId() + ')');

        // ── STEP 1: Fetch tracking record ────────────────────────────────────────
        System.debug(LOG + 'STEP 1 — Querying Panda_Docs_Document__c for DocumentId__c=' + documentId);

        List<Panda_Docs_Document__c> tracking = [
            SELECT Id, Name,
                   Lead_Opportunity__c,
                   Lead_Opportunity__r.Primary_Contact__c,
                   Lead_Opportunity__r.AccountId,
                   DocumentID__c,
                   Status__c
            FROM   Panda_Docs_Document__c
            WHERE  DocumentId__c = :documentId WITH SYSTEM_MODE
            LIMIT  1
        ];

        if (tracking.isEmpty()) {
            System.debug(LOG + 'STEP 1 FAILED — No record found for DocumentId__c=' + documentId);
            System.debug(LOG + '========== ABORTED ==========');
            return;
        }

        Panda_Docs_Document__c rec = tracking[0];
        System.debug(LOG + 'STEP 1 OK — Id=' + rec.Id + ' Name=' + rec.Name + ' Status=' + rec.Status__c);
        System.debug(LOG + '  Lead_Opportunity__c         : ' + rec.Lead_Opportunity__c);
        System.debug(LOG + '  Primary_Contact__c (via opp): ' + rec.Lead_Opportunity__r.Primary_Contact__c);
        System.debug(LOG + '  AccountId (via opp)         : ' + rec.Lead_Opportunity__r.AccountId);

        if (rec.Lead_Opportunity__c == null) {
            System.debug(LOG + 'WARNING — Lead_Opportunity__c is null. PDF will only attach to Panda Doc record.');
        }
        if (rec.Lead_Opportunity__r.Primary_Contact__c == null) {
            System.debug(LOG + 'WARNING — Primary_Contact__c is null. PDF will NOT attach to a Contact.');
        }
        if (rec.Lead_Opportunity__r.AccountId == null) {
            System.debug(LOG + 'WARNING — AccountId is null. PDF will NOT attach to an Account.');
        }

        // ── STEP 2: Download signed PDF ──────────────────────────────────────────
        System.debug(LOG + 'STEP 2 — Downloading PDF for documentId=' + documentId);

        Blob pdfBlob = downloadDocument(documentId);

        if (pdfBlob == null) {
            System.debug(LOG + 'STEP 2 FAILED — PDF download returned null.');
            System.debug(LOG + 'ACTION REQUIRED — Check Named Credential and PandaDoc API status.');
            System.debug(LOG + '========== ABORTED ==========');
            return;
        }

        System.debug(LOG + 'STEP 2 OK — PDF downloaded. Blob size (bytes)=' + pdfBlob.size());

        // ── STEP 3: Insert ContentVersion ────────────────────────────────────────
        System.debug(LOG + 'STEP 3 — Inserting ContentVersion. Title=' + rec.Name);

        ContentVersion cv = new ContentVersion(
            Title        = rec.Name,
            PathOnClient = rec.Name + '.pdf',
            VersionData  = pdfBlob,
			FirstPublishLocationId = rec.Id,
			OwnerId = '005PZ0000015xwXYAQ'
        );

        try {
            insert cv;
            System.debug(LOG + 'STEP 3 OK — ContentVersion inserted. Id=' + cv.Id);
        } catch (Exception e) {
            System.debug(LOG + 'STEP 3 FAILED — ' + e.getMessage());
            System.debug(LOG + 'Stack: ' + e.getStackTraceString());
            System.debug(LOG + '========== ABORTED ==========');
            return;
        }

        Id contentDocId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
        ].ContentDocumentId;
        System.debug(LOG + 'STEP 3 OK — ContentDocumentId: ' + contentDocId);

        // ── STEP 4: Insert ContentDocumentLinks ──────────────────────────────────
        System.debug(LOG + 'STEP 4 — Building ContentDocumentLinks.');

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        System.debug(LOG + '  Linking to Panda Doc record : ' + rec.Id);
        links.add(makeLink(contentDocId, rec.Id));

        if (rec.Lead_Opportunity__c != null) {
            System.debug(LOG + '  Linking to Opportunity      : ' + rec.Lead_Opportunity__c);
            links.add(makeLink(contentDocId, rec.Lead_Opportunity__c));
        } else {
            System.debug(LOG + '  SKIPPED Opportunity — null.');
        }

        if (rec.Lead_Opportunity__r.Primary_Contact__c != null) {
            System.debug(LOG + '  Linking to Contact          : ' + rec.Lead_Opportunity__r.Primary_Contact__c);
            links.add(makeLink(contentDocId, rec.Lead_Opportunity__r.Primary_Contact__c));
        } else {
            System.debug(LOG + '  SKIPPED Contact — null.');
        }

        if (rec.Lead_Opportunity__r.AccountId != null) {
            System.debug(LOG + '  Linking to Account          : ' + rec.Lead_Opportunity__r.AccountId);
            links.add(makeLink(contentDocId, rec.Lead_Opportunity__r.AccountId));
        } else {
            System.debug(LOG + '  SKIPPED Account — null.');
        }

        System.debug(LOG + 'STEP 4 — Total links to insert: ' + links.size());

        try {
            insert links;
            System.debug(LOG + 'STEP 4 OK — ContentDocumentLinks inserted.');
        } catch (Exception e) {
            System.debug(LOG + 'STEP 4 FAILED — ' + e.getMessage());
            System.debug(LOG + 'Stack: ' + e.getStackTraceString());
            System.debug(LOG + '========== ABORTED ==========');
            return;
        }

        // ── STEP 5: Update Status__c = Completed ─────────────────────────────────
        System.debug(LOG + 'STEP 5 — Updating Status__c to Completed. Record Id=' + rec.Id);

        try {
            rec.Status__c = 'Completed';
            update rec;
            System.debug(LOG + 'STEP 5 OK — Status__c = Completed.');
        } catch (Exception e) {
            System.debug(LOG + 'STEP 5 FAILED — ' + e.getMessage());
            System.debug(LOG + 'Stack: ' + e.getStackTraceString());
        }

        System.debug(LOG + '========== COMPLETED SUCCESSFULLY ==========');
        System.debug(LOG + 'Summary:');
        System.debug(LOG + '  DocumentId        : ' + documentId);
        System.debug(LOG + '  ContentDocumentId : ' + contentDocId);
        System.debug(LOG + '  Links inserted    : ' + links.size());
        System.debug(LOG + '  Final Status      : Completed');
    }

    // ── Private helpers ──────────────────────────────────────────────────────────

    private Blob downloadDocument(String docId) {
        try {
            String endpoint = 'callout:PandaDoc/public/v1/documents/' + docId + '/download';
            System.debug(LOG + '  GET ' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');

            HttpResponse res = new Http().send(req);
            System.debug(LOG + '  HTTP Status  : ' + res.getStatusCode() + ' ' + res.getStatus());
            System.debug(LOG + '  Content-Type : ' + res.getHeader('Content-Type'));

            if (res.getStatusCode() == 200) {
                System.debug(LOG + '  Download OK — ' + res.getBodyAsBlob().size() + ' bytes.');
                return res.getBodyAsBlob();
            }

            System.debug(LOG + '  Download FAILED — Response: ' + res.getBody());

        } catch (Exception e) {
            System.debug(LOG + '  Download EXCEPTION: ' + e.getMessage());
            System.debug(LOG + '  Stack: ' + e.getStackTraceString());
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