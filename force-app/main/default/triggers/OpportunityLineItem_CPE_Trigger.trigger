/**************************************************************
* Keeps Opportunity.CPE_Order__c in step with the Opportunity's products.
* Logic in OpportunityLineItemCPEService.class
* (A product line can't change its product or Opportunity once created, and
* product lines can't be undeleted, so only insert and delete are handled.)
***************************************************************/
trigger OpportunityLineItem_CPE_Trigger on OpportunityLineItem (after insert, after delete) {
    OpportunityLineItemCPEService.syncCPEOrder(Trigger.isDelete ? Trigger.old : Trigger.new);
}
