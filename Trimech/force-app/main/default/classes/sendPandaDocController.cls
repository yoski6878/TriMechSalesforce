/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : sendPandaDocController
 * Author          : <YourName>
 * Created Date    : Apr 29, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Apr 29, 2026
 * Description     : LWC controller — fetches templates and kicks off document
 *                   creation via pandaDocsIntegration.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 29, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class sendPandaDocController {

    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getTemplates() {
        List<TemplateOption> options = new List<TemplateOption>();
        for (Panda_Docs_TemplateDocument__mdt mdt :
            [SELECT MasterLabel, Template_Id__c FROM Panda_Docs_TemplateDocument__mdt]) {
            TemplateOption opt = new TemplateOption();
            opt.label = mdt.MasterLabel;
            opt.value = mdt.Template_Id__c;
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled
    public static void sendDocument(Id opportunityId, String templateId, String documentName) {
        Map<String, Object> payload = pandaDocsIntegration.buildPayload(opportunityId, templateId);
        pandaDocsIntegration.createPandaDoc(payload, opportunityId, documentName);
    }

    public class TemplateOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}