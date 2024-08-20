/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Asset object.
 *
 *********************************************************/
public without sharing class Asset_Trigger {
    
    public static void beforeInsert(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
		//Implement business logic
	}
	  
	public static void beforeUpdate(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
	  	//Implement business logic	  	
	}
	  
    public static void beforeDelete(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
	  	//Implement business logic	  	
	}
		
	public static void afterInsert(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
		
        /*Set<Id> accountsWithAssetInserts = new Set<Id>();
        List<Asset_Summary__c> newAssetSummaries = new List<Asset_Summary__c>{};
        for(Asset a : newList){
        	accountsWithAssetInserts.add(a.AccountId);	        
        }
        if(!accountsWithAssetInserts.isEmpty()) {
            //createAssetSummaries(accountsWithAssetInserts);
        }
        AssetBatchable assetBatch = new AssetBatchable(newList);
        Database.executeBatch(assetBatch,200);*/
        
        /*List<Asset> assetList = new List<Asset>();
        assetList.addAll(newList);
        AssetQueueable assetQueue = new AssetQueueable(assetList,10);
        System.enqueueJob(assetQueue);*/

        Set<Id> accounts = new Set<Id>();
        
        for(Asset a : newList) {
            accounts.add(a.AccountId);
        }

        List<Id> acctList = new List<Id>(accounts);
        System.debug(acctList);

        AccountSummarizeAssetsQueueable queue = new AccountSummarizeAssetsQueueable(acctList);
        System.enqueueJob(queue);
    }
	
	public static void afterUpdate(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
		
        /*Set<Id> accountsWithAssetUpdates = new Set<Id>();
        for(Asset a : newList){
        	accountsWithAssetUpdates.add(a.AccountId);	        
        }
        if(!accountsWithAssetUpdates.isEmpty()) createAssetSummaries(accountsWithAssetUpdates);
        AssetBatchable assetBatch = new AssetBatchable(newList);
        Database.executeBatch(assetBatch,200);*/
        
        /*List<Asset> assetList = new List<Asset>();
        assetList.addAll(newList);
        AssetQueueable assetQueue = new AssetQueueable(assetList,10);
        System.enqueueJob(assetQueue);*/

        Set<Id> accounts = new Set<Id>();
        
        for(Asset a : newList) {
            accounts.add(a.AccountId);
        }

        List<Id> acctList = new List<Id>(accounts);

        AccountSummarizeAssetsQueueable queue = new AccountSummarizeAssetsQueueable(acctList);
        System.enqueueJob(queue);
	}
	
	public static void afterDelete(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
	  	
	  	/*Set<Id> accountsWithAssetDeletes = new Set<Id>();
        for(Asset a : oldList){
        	accountsWithAssetDeletes.add(a.AccountId);	        
        }
        if(!accountsWithAssetDeletes.isEmpty()) createAssetSummaries(accountsWithAssetDeletes);
        AssetBatchable assetBatch = new AssetBatchable(oldList);
        Database.executeBatch(assetBatch,200);*/
        
        /*List<Asset> assetList = new List<Asset>();
        assetList.addAll(oldList);
        AssetQueueable assetQueue = new AssetQueueable(assetList,10);
        System.enqueueJob(assetQueue);*/

        Set<Id> accounts = new Set<Id>();
        
        for(Asset a : oldList) {
            accounts.add(a.AccountId);
        }

        List<Id> acctList = new List<Id>(accounts);

        AccountSummarizeAssetsQueueable queue = new AccountSummarizeAssetsQueueable(acctList);
        System.enqueueJob(queue);
	}
	
	/*public static void afterUnDelete(List<Asset> newList,List<Asset> oldList, Map<Id,Asset> newMap, Map<Id,Asset> oldMap){
	  	//Implement business logic		
	}*/	
	
	/*public static void createAssetSummaries(Set<Id> accountIds) {
		
        delete new List<Asset_Summary__c>([SELECT Id FROM Asset_Summary__c WHERE Account__c IN :accountIds]);
        
        Asset_Summary__c[] newAssetSummaries = new Asset_Summary__c[]{};
        for(Account acc : [SELECT Id, (SELECT Id, Asset_Group__c, Quantity FROM Assets WHERE Status = 'Active' AND Asset_Group__c != null AND Quantity != null) FROM Account WHERE Id IN :accountIds]){
            if(!acc.Assets.isEmpty()){
                Map<String,Decimal> groupToQuantity = new Map<String,Decimal>();
                for(Asset a : acc.Assets){
                	Decimal qnt = a.Quantity;
                    if(groupToQuantity.containsKey(a.Asset_Group__c)) qnt += groupToQuantity.get(a.Asset_Group__c);
                    groupToQuantity.put(a.Asset_Group__c,qnt);
                }
                
                for(String grpType : groupToQuantity.keySet()){
                    if(groupToQuantity.get(grpType) > 0.0) newAssetSummaries.add(new Asset_Summary__c(Account__c = acc.Id, Asset_Group__c = grpType, Asset_Count__c = groupToQuantity.get(grpType)));
                }
            }
        }
        
        if(!newAssetSummaries.isEmpty()) insert newAssetSummaries;
	}*/
}