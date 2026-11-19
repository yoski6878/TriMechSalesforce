public without sharing class CommissionableGPSyncService {
    public static void syncForLineItems(List<OpportunityLineItem> lineItems) {
        Set<Id> opportunityIds = new Set<Id>();
        for (OpportunityLineItem lineItem : lineItems) {
            if (lineItem.OpportunityId != null) {
                opportunityIds.add(lineItem.OpportunityId);
            }
        }

        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> commissionableGPByOpportunity = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT OpportunityId opportunityId, SUM(Commissionable_GP__c) commissionableGP
            FROM OpportunityLineItem
            WHERE OpportunityId IN :opportunityIds
            GROUP BY OpportunityId
        ]) {
            commissionableGPByOpportunity.put(
                (Id) result.get('opportunityId'),
                (Decimal) result.get('commissionableGP')
            );
        }

        List<Opportunity> updates = new List<Opportunity>();
        for (Opportunity opportunity : [
            SELECT Id, IsClosed, Probability, Updated_via_Sales_Order__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]) {
            // Sales Order automation owns finalized values. Closed Opportunities
            // are also left unchanged so historical/booked GP is not rewritten.
            if (opportunity.IsClosed || opportunity.Updated_via_Sales_Order__c) {
                continue;
            }

            Decimal commissionableGP = commissionableGPByOpportunity.containsKey(opportunity.Id)
                ? commissionableGPByOpportunity.get(opportunity.Id)
                : 0;
            Decimal probability = opportunity.Probability == null ? 0 : opportunity.Probability;

            updates.add(new Opportunity(
                Id = opportunity.Id,
                Commissionable_GP_Currency__c = commissionableGP,
                Weighted_Commissionable_GP__c = commissionableGP * probability / 100
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
