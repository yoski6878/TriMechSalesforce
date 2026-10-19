/**
* @File Name : OpportunityLineItemCPEService.cls
* @Description : Keeps Opportunity.CPE_Order__c in step with the Opportunity's
*   products. CPE_Order__c is 'Yes' when any line item's product is OEM Dassault
*   in the Enterprise Solutions business unit, otherwise 'No'. Called from
*   OpportunityLineItem_CPE_Trigger when products are added or removed.
*   Only writes when the answer changes, and never touches an Opportunity that is
*   waiting for its NetSuite Id, because updating it would send it to NetSuite again.
**/

public without sharing class OpportunityLineItemCPEService {
    @TestVisible private static final String CPE_OEM = 'Dassault';
    @TestVisible private static final String CPE_BUSINESS_UNIT = 'Enterprise Solutions';
    private static final String SEND_TO_OM_STAGE = 'Send to Order Management';

    public static void syncCPEOrder(List<OpportunityLineItem> lines) {
        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem line : lines) {
            if (line.OpportunityId != null) {
                oppIds.add(line.OpportunityId);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }

        Set<Id> cpeOppIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT OpportunityId oppId
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
              AND Product2.OEM__c = :CPE_OEM
              AND Product2.Business_Unit__c = :CPE_BUSINESS_UNIT
            GROUP BY OpportunityId
        ]) {
            cpeOppIds.add((Id) ar.get('oppId'));
        }

        List<Opportunity> toUpdate = new List<Opportunity>();
        for (Opportunity opp : [
            SELECT Id, CPE_Order__c, StageName, celigo_sfnsio__NetSuite_Id__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ]) {
            Boolean isCpe = cpeOppIds.contains(opp.Id);
            Boolean wasCpe = opp.CPE_Order__c == 'Yes';
            if (isCpe == wasCpe) {
                continue;
            }
            if (opp.StageName == SEND_TO_OM_STAGE && String.isBlank(opp.celigo_sfnsio__NetSuite_Id__c)) {
                continue;
            }
            toUpdate.add(new Opportunity(Id = opp.Id, CPE_Order__c = isCpe ? 'Yes' : 'No'));
        }

        if (!toUpdate.isEmpty()) {
            for (Database.SaveResult result : Database.update(toUpdate, false)) {
                if (!result.isSuccess()) {
                    System.debug(LoggingLevel.WARN, 'CPE_Order__c sync failed: ' + result.getErrors());
                }
            }
        }
    }
}
