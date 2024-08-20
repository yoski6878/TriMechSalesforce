public with sharing class AccountSummarizeAssetsQueueable implements Queueable {

    //public Set<Id> accountIds;
    public List<Id> acctIds;

    public AccountSummarizeAssetsQueueable(List<Id> acctIds) {
        this.acctIds = acctIds;
    }

    public void execute(QueueableContext context) {
        System.debug(acctIds);
        if(!acctIds.isEmpty()) {
            Id acct = acctIds.remove(0);
            Database.delete(new List<Asset_Summary__c>([SELECT Id FROM Asset_Summary__c WHERE Account__c = :acct]),false);
        
            Asset_Summary__c[] newAssetSummaries = new Asset_Summary__c[]{};

            /*
            //List<Asset> acctAssets = [SELECT Id, Asset_Group__c, Quantity FROM Asset WHERE Status = 'Active' AND Asset_Group__c != null AND Quantity != null AND AccountId = :acct];
            List<Asset> acctAssets = [SELECT Id, Asset_Group__c, Quantity FROM Asset WHERE Asset_Group__c != null AND Quantity != null AND AccountId = :acct];

            if(!acctAssets.isEmpty()) {
                Map<String,Decimal> groupToQuantity = new Map<String,Decimal>();
                for(Asset a : acctAssets){
                	Decimal qnt = a.Quantity;
                    if(groupToQuantity.containsKey(a.Asset_Group__c)) qnt += groupToQuantity.get(a.Asset_Group__c);
                    groupToQuantity.put(a.Asset_Group__c,qnt);
                }
                
                for(String grpType : groupToQuantity.keySet()){
                    if(groupToQuantity.get(grpType) > 0.0) newAssetSummaries.add(new Asset_Summary__c(Account__c = acct, Asset_Group__c = grpType, Asset_Count__c = groupToQuantity.get(grpType), Upsert_Key__c = acct + grpType));
                }
            } */
            List<Asset> acctAssets = [SELECT Id, Asset_Group__c, Quantity, Status, RecordTypeId FROM Asset WHERE Asset_Group__c != null AND Quantity != null AND AccountId = :acct];
            String recordTypeSoftware = System.Label.Asset_RecordTypeId_Software;
            if(!acctAssets.isEmpty()) {
                Map<String,Decimal> groupToQuantity = new Map<String,Decimal>();
                for(Asset a : acctAssets){
                    if(a.RecordTypeId == recordTypeSoftware) {
                        Decimal qnt = a.Quantity;
                        if(groupToQuantity.containsKey(a.Asset_Group__c)) {qnt += groupToQuantity.get(a.Asset_Group__c);}
                        groupToQuantity.put(a.Asset_Group__c,qnt);
                    }
                    else if (a.Status == 'Active') {
                        Decimal qnt = a.Quantity;
                        if(groupToQuantity.containsKey(a.Asset_Group__c)) {qnt += groupToQuantity.get(a.Asset_Group__c);}
                        groupToQuantity.put(a.Asset_Group__c,qnt);
                    }
                }
                
                for(String grpType : groupToQuantity.keySet()){
                    if(groupToQuantity.get(grpType) > 0.0) {newAssetSummaries.add(new Asset_Summary__c(Account__c = acct, Asset_Group__c = grpType, Asset_Count__c = groupToQuantity.get(grpType), Upsert_Key__c = acct + grpType));}
                }
            }
            
            if (!newAssetSummaries.isEmpty()) {
                try {
                    upsert newAssetSummaries Upsert_Key__c;  // This line upserts the asset summary list with
                                            // the Upsert_Key__c (account id + group) field specified as the 
                                            // field that should be used for matching
                                            // the record that should be upserted. 
                } catch (DmlException e) {
                    System.debug(e.getMessage());
                }
            }

            if(!acctIds.isEmpty()) {
                AccountSummarizeAssetsQueueable q = new AccountSummarizeAssetsQueueable(acctIds);
                if (!Test.isRunningTest()) System.enqueueJob(q);
            }
        }
    }
}