public with sharing class LeadConvertBatchable implements Database.Batchable<Lead> {
    public List<Lead> leads;

    public LeadConvertBatchable(List<Lead> leads) {
        this.leads = leads;
    }

    public List<Lead> start(Database.BatchableContext bc) {
        return leads;
    }

    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        LeadConvert.convertLeads(scope);
    }

    public void finish(Database.BatchableContext bc) {}
}