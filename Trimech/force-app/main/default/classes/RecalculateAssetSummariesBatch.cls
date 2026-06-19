/**
 * Batch Apex to recalculate asset summary records for all Accounts with Assets.
 *
 * Security: This batch runs in system mode and does NOT enforce FLS or sharing on Account, Asset, or Asset_Summary__c.
 * This is intentional for maintenance purposes. If summaries become user-facing or permission-sensitive, add FLS/sharing enforcement in AccountAssetSummaryService.
 *
 * Usage: Execute with Database.executeBatch(new RecalculateAssetSummariesBatch(), 2000);
 */
public class RecalculateAssetSummariesBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        //System.debug(LoggingLevel.INFO, '[RecalculateAssetSummariesBatch] Batch started.');
        // Use a semi-join to get all Accounts with Assets (scalable, paginates), ordered for deterministic batching
        return Database.getQueryLocator('SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Asset WHERE AccountId != null) ORDER BY Id');
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> acctIds = new Set<Id>();
        for (SObject s : scope) {
            acctIds.add(((Account)s).Id);
        }
        //System.debug(LoggingLevel.INFO, '[RecalculateAssetSummariesBatch] Processing chunk. Account count: ' + acctIds.size());
        if (!acctIds.isEmpty()) {
            AccountAssetSummaryService.recalculate(acctIds);
        }
    }

    public void finish(Database.BatchableContext bc) {
        //System.debug(LoggingLevel.INFO, '[RecalculateAssetSummariesBatch] Batch finished.');
    }
}