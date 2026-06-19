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
            // Query accounts with filtered assets; no RecordTypeId filter here per requirements
            for (Account acc : [
                SELECT Id,
                    (SELECT Id, AccountId, Quantity, Asset_Type__c, Product2Id
                     FROM Assets
                     WHERE Status IN ('Active','Active w/o subscription / maintenance')
                       AND Quantity != null)
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                if (!acc.Assets.isEmpty()) {
                    // Preload Product2s for this account's assets
                    Set<Id> pIds = new Set<Id>();
                    for (Asset a : acc.Assets) {
                        if (a.Product2Id != null) pIds.add(a.Product2Id);
                    }
                    Map<Id, Product2> pMap = new Map<Id, Product2>();
                    if (!pIds.isEmpty()) {
                        for (Product2 p : [SELECT Id, Class__c, Technology__c FROM Product2 WHERE Id IN :pIds]) {
                            pMap.put(p.Id, p);
                        }
                    }

                    // Aggregate by new key: AccountId|Asset_Type__c|(Class if Software else Technology)
                    Map<String, Decimal> keyToQty = new Map<String, Decimal>();
                    Map<String, String> keyToType = new Map<String, String>();
                    Map<String, String> keyToClass = new Map<String, String>();
                    Map<String, String> keyToTech = new Map<String, String>();

                    for (Asset a : acc.Assets) {
                        String typeVal = a.Asset_Type__c;
                        Product2 p = (a.Product2Id != null ? pMap.get(a.Product2Id) : null);
                        Boolean isSoftware = (String.valueOf(typeVal) == 'Software');
                        String classVal = isSoftware ? (p != null ? p.Class__c : null) : null;
                        String techVal = isSoftware ? null : (p != null ? p.Technology__c : null);
                        String third = isSoftware ? classVal : techVal;
                        String key = String.valueOf(a.AccountId) + '|' + String.valueOf(typeVal) + '|' + String.valueOf(third);

                        Decimal q = a.Quantity;
                        if (keyToQty.containsKey(key)) q += keyToQty.get(key);
                        keyToQty.put(key, q);
                        keyToType.put(key, typeVal);
                        keyToClass.put(key, classVal);
                        keyToTech.put(key, techVal);
                    }

                    for (String key : keyToQty.keySet()) {
                        Decimal total = keyToQty.get(key);
                        if (total > 0) {
                            newAssetSummaries.add(new Asset_Summary__c(
                                Account__c = acc.Id,
                                Asset_Type__c = keyToType.get(key),
                                Asset_Class__c = keyToClass.get(key),
                                Asset_Technology__c = keyToTech.get(key),
                                Asset_Count__c = total,
                                Upsert_Key__c = key
                            ));
                        }
                    }
                }
            }
        
            if(!newAssetSummaries.isEmpty()) upsert newAssetSummaries Upsert_Key__c;
            
            if(assets.size() >= jobSize) {
                AssetQueueable q = new AssetQueueable(assets,jobSize);
                if (!Test.isRunningTest()) System.enqueueJob(q);
            }
        }
    }
}