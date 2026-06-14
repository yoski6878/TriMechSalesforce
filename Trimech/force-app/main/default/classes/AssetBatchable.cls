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
                        // Build key with fixed-length segments to fit within 30 chars:
                        // AccountId(15)|Type(2)|ThirdPart(11)
                        String accIdPart = String.valueOf(a.AccountId).substring(0, Math.min(15, String.valueOf(a.AccountId).length()));
                        String typePart = String.valueOf(typeVal).substring(0, Math.min(2, String.valueOf(typeVal).length()));
                        String thirdPart = String.valueOf(third).substring(0, Math.min(11, String.valueOf(third).length()));
                        String key = accIdPart + '|' + typePart + '|' + thirdPart;

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
            
        }

        
    }

    public void finish(Database.BatchableContext bc) {}
}