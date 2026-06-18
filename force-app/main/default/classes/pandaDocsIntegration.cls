/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : pandaDocsIntegration
 * Author          : <YourName>
 * Created Date    : Apr 29, 2026
 * Last Modified By: <YourName>
 * Last Modified On: May 14, 2026
 * Description     : Core integration class. Builds PandaDoc payload, creates
 *                   the document via API, persists tracking record and enqueues
 *                   PandaDocSendQueueable to poll and send.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 29, 2026  │ <YourName>   │ Initial version
 *  May 14, 2026  │ <YourName>   │ Replaced sendPandaDocDocument() blind
 *                │              │ System.schedule() with PandaDocSendQueueable
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class pandaDocsIntegration {


    // ── Payload builder ──────────────────────────────────────────────────────────
    public static Map<String, Object> buildPayload(Id recordId, String templateId) {

        Map<String, Object>       payload    = new Map<String, Object>();
        List<Map<String, Object>> tokens     = new List<Map<String, Object>>();
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();

        payload.put('template_uuid', templateId);

        List<Opportunity> opp = [
            SELECT Id, Name, Amount, CloseDate, Description,
                   Account.Name, Account.Phone, Account.Website,
                   Account.BillingCity, Account.BillingState,
                   Owner.FirstName, Owner.LastName, Owner.Email, Owner.Name,
                   Primary_Contact__c,
                   Primary_Contact__r.FirstName, Primary_Contact__r.LastName,
                   Primary_Contact__r.Email, Primary_Contact__r.Phone,
                   Primary_Contact__r.MailingStreet
            FROM   Opportunity
            WHERE  Id = :recordId
            LIMIT  1
        ];

        if (!opp.isEmpty()) {
            tokens.add(createToken('Client.Company',           opp[0].Account?.Name));
            tokens.add(createToken('Company.Name',             opp[0].Account?.Name));
            tokens.add(createToken('Company.City',             opp[0].Account?.BillingCity));
            tokens.add(createToken('Company.State',            opp[0].Account?.BillingState));
            tokens.add(createToken('Company.Phone',            opp[0].Account?.Phone));
            tokens.add(createToken('Company.Website',          opp[0].Account?.Website));
            tokens.add(createToken('company name',             opp[0].Account?.Name));
            tokens.add(createToken('Deal.Amount',              String.valueOf(opp[0].Amount)));
            tokens.add(createToken('Deal.CloseDate',           String.valueOf(opp[0].CloseDate)));
            tokens.add(createToken('Deal.DealName',            opp[0].Name));
            tokens.add(createToken('Deal.Description',         opp[0].Description));
            tokens.add(createToken('Sender.FirstName',         opp[0].Owner.FirstName));
            tokens.add(createToken('Sender.LastName',          opp[0].Owner.LastName));
            tokens.add(createToken('Sender.Company',           'Mako Design'));
            tokens.add(createToken('Quote.Number',             opp[0].Id));
            tokens.add(createToken('Project Name',             opp[0].Name));
            tokens.add(createToken('project name',             opp[0].Name));
            tokens.add(createToken('date created',             Datetime.now().format('yyyy-MM-dd')));
            tokens.add(createToken('Completion Estimate',      '90'));
            tokens.add(createToken('Document.ExpirationDate',  Datetime.now().addDays(90).format('yyyy-MM-dd')));
            tokens.add(createToken('Contact.FirstName',        opp[0].Primary_Contact__r?.FirstName));
            tokens.add(createToken('Contact.LastName',         opp[0].Primary_Contact__r?.LastName));
            tokens.add(createToken('Contact.Email',            opp[0].Primary_Contact__r?.Email));
            tokens.add(createToken('Contact.Phone',            opp[0].Primary_Contact__r?.Phone));
            tokens.add(createToken('Contact.Address',          opp[0].Primary_Contact__r?.MailingStreet));

            recipients.add(createRecipient(
                opp[0].Primary_Contact__r?.Email,
                opp[0].Primary_Contact__r?.FirstName,
                opp[0].Primary_Contact__r?.LastName,
                'Client'
            ));

            payload.put('tokens',     tokens);
            payload.put('recipients', recipients);
        }

        return payload;
    }

    // ── Document creation ────────────────────────────────────────────────────────

    public static void createPandaDoc(Map<String, Object> payload, String recordId, String documentName) {

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:PandaDoc/public/v1/documents');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 201) {

            Map<String, Object> response  = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String              documentId = (String) response.get('id');
            String              status     = (String) response.get('status');

            System.debug('PandaDoc Document Created: ' + documentId + ' | ' + status);

            Panda_Docs_Document__c pd = new Panda_Docs_Document__c(
                Lead_Opportunity__c = recordId,
                DocumentID__c       = documentId,
                Status__c           = status,
                Name                = documentName,
                PDF_Attached__c     = false,
                Fetch_Retry_Count__c = 0,
                Fetch_Status__c     = 'Pending'
            );
            insert pd;

            // Enqueue send with 2 minute initial delay
            System.enqueueJob(new PandaDocSendQueueable(documentId), 2);

        } else {
            System.debug('PandaDoc Error: ' + res.getBody());
        }
    }

    private static Map<String, Object> createToken(String name, String value) {
        return new Map<String, Object>{
            'name'  => name,
            'value' => value != null ? value : ''
        };
    }

    private static Map<String, Object> createRecipient(String email, String firstName, String lastName, String role) {
        return new Map<String, Object>{
            'email'      => email,
            'first_name' => firstName,
            'last_name'  => lastName,
            'role'       => role
        };
    }
}