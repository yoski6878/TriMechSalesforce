public with sharing class AssetBatchable implements Database.Batchable<Asset>{
    public List<Asset> assets;

    public AssetBatchable(List<Asset> assets) {
        this.assets = assets;
    }

    public List<Asset> start(Database.BatchableContext bc) {
        return assets;
    }

    public void execute(Database.BatchableContext bc, List<Asset> scope) {
        //pass in assets and get account ids
        Set<Id> accountIds = new Set<Id>();
        
        for(Asset a : assets){
        	accountIds.add(a.AccountId);	        
        }
        if(!accountIds.isEmpty()) {
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
            
        }

        
    }

    public void finish(Database.BatchableContext bc) {}
}