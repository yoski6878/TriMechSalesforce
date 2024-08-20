public with sharing class AssetQueueable implements Queueable {

    public List<Asset> assets;
    public Integer jobSize;

    public AssetQueueable(List<Asset> assets, Integer jobSize) {
        this.assets = assets;
        this.jobSize = jobSize;
    }

    public void execute(QueueableContext context) {
        Set<Id> accountIds = new Set<Id>();
        
        List<Asset> assetBatch = new List<Asset>();
        
        //adds 50 assets to a batch
        if(assets.size() >= jobSize) {
            for(Integer i = 0; i < jobSize; i++) {
                assetBatch.add(assets.get(i));
            }
        }
        //adds remaining number of assets to a batch if there are less than 50
        else {
            for(Integer i = 0; i < assets.size(); i++) {
                assetBatch.add(assets.get(i));
            }
        }
        //removes current 50 assets from the full list
        if(assets.size() >= jobSize) {
            for(Integer i = jobSize - 1; i >= 0; i--) {
                assets.remove(i);
            }
        }
        //removes remaining assets from the full list if there are less than 50
        else {
            for(Integer i = assets.size()-1; i >= 0; i--) {
                assets.remove(i);
            }
        }

        //get subset of 50 and loop through them
        for(Asset a : assetBatch){
        	accountIds.add(a.AccountId);	        
        }
        if(!accountIds.isEmpty()) {
            Database.delete(new List<Asset_Summary__c>([SELECT Id FROM Asset_Summary__c WHERE Account__c IN :accountIds]),false);
        
            Asset_Summary__c[] newAssetSummaries = new Asset_Summary__c[]{};
            //for(Account acc : [SELECT Id, (SELECT Id, Asset_Group__c, Quantity FROM Assets WHERE Status = 'Active' AND Asset_Group__c != null AND Quantity != null) FROM Account WHERE Id IN :accountIds]){
            for(Account acc : [SELECT Id, (SELECT Id, Asset_Group__c, Quantity FROM Assets WHERE Asset_Group__c != null AND Quantity != null) FROM Account WHERE Id IN :accountIds]){
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
            
            if(assets.size() >= jobSize) {
                AssetQueueable q = new AssetQueueable(assets,jobSize);
                if (!Test.isRunningTest()) System.enqueueJob(q);
            }
        }
    }
}