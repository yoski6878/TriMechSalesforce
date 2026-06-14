/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Asset object.
 *
 *********************************************************/
public without sharing class Asset_Trigger {
        public static void beforeInsert(List<Asset> newList, List<Asset> oldList, Map<Id, Asset> newMap, Map<Id, Asset> oldMap) {
            if (newList == null || oldList == null || newMap == null || oldMap == null) {
                return;
            }
            // No logic needed for before insert
        }

        public static void beforeUpdate(List<Asset> newList, List<Asset> oldList, Map<Id, Asset> newMap, Map<Id, Asset> oldMap) {
            if (newList == null || oldList == null || newMap == null || oldMap == null) {
                return;
            }
            // No logic needed for before update
        }

        public static void beforeDelete(List<Asset> newList, List<Asset> oldList, Map<Id, Asset> newMap, Map<Id, Asset> oldMap) {
            if (newList == null || oldList == null || newMap == null || oldMap == null) {
                return;
            }
            // No logic needed for before delete
        }
    
    // Private helper method to batch and enqueue account summary jobs
    private static void batchAndEnqueueAccountJobs(List<Asset> assets, String context) {
        // Get all account IDs from assets
        Set<Id> allAccounts = new Set<Id>();
        for(Asset a : assets) {
            if(a.AccountId != null) {
                allAccounts.add(a.AccountId);
            }
        }
        
        // Separate accounts with High_Asset_Inventory__c flag into individual jobs
        Set<Id> highVolumeAccounts = new Set<Id>();
        Set<Id> normalAccounts = new Set<Id>();
        
        if(!allAccounts.isEmpty()) {
            // Query accounts that have the High_Asset_Inventory__c flag set
            for(Account acc : [
                SELECT Id 
                FROM Account 
                WHERE Id IN :allAccounts 
                  AND High_Asset_Inventory__c = true
            ]) {
                highVolumeAccounts.add(acc.Id);
            }
            
            // Find accounts without the flag
            for(Id accId : allAccounts) {
                if(!highVolumeAccounts.contains(accId)) {
                    normalAccounts.add(accId);
                }
            }
        }
        
        // Process high-volume accounts individually (one job per account)
        for(Id accountId : highVolumeAccounts) {
            List<Id> singleAccountList = new List<Id>{accountId};
            AccountSummarizeAssetsQueueable queue = new AccountSummarizeAssetsQueueable(singleAccountList);
            System.enqueueJob(queue);
        }
        
        // Process normal accounts with batching
        if(!normalAccounts.isEmpty()) {
            // Create batches of account IDs to reduce job count
            List<List<Id>> accountBatches = new List<List<Id>>();
            Integer batchSize = 500; // Increased batch size as requested
            List<Id> currentBatch = new List<Id>();
            
            for(Id accountId : normalAccounts) {
                currentBatch.add(accountId);
                if(currentBatch.size() >= batchSize) {
                    accountBatches.add(currentBatch);
                    currentBatch = new List<Id>();
                }
            }
            
            // Add remaining accounts if any
            if(!currentBatch.isEmpty()) {
                accountBatches.add(currentBatch);
            }
            
            // Create one Queueable job per batch
            for(List<Id> batch : accountBatches) {
                AccountSummarizeAssetsQueueable queue = new AccountSummarizeAssetsQueueable(batch);
                System.enqueueJob(queue);
            }
        }
    }
    
	public static void afterInsert(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
        try {
            batchAndEnqueueAccountJobs(newList, 'afterInsert');
        } catch(Exception e) {
            // Log the error and continue - this is a best-effort async operation
            System.debug('ERROR: Failed to enqueue account summary jobs for afterInsert: ' + e.getMessage());
        }
    }
	
	public static void afterUpdate(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
        try {
            batchAndEnqueueAccountJobs(newList, 'afterUpdate');
        } catch(Exception e) {
            // Log the error and continue - this is a best-effort async operation
            System.debug('ERROR: Failed to enqueue account summary jobs for afterUpdate: ' + e.getMessage());
        }
    }
	
	public static void afterDelete(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
        try {
            batchAndEnqueueAccountJobs(oldList, 'afterDelete');
        } catch(Exception e) {
            // Log the error and continue - this is a best-effort async operation
            System.debug('ERROR: Failed to enqueue account summary jobs for afterDelete: ' + e.getMessage());
        }
    }
}