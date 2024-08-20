public without sharing class AddProductToOpportunityController {

    @AuraEnabled
    public static list<dataWrapper> getProductData(Id opportunityId) {

        Opportunity opp = [SELECT Id, Name, Pricebook2Id, currencyISOCode FROM Opportunity WHERE Id =: opportunityId];

        Id priceBookId = opp.Pricebook2Id;
        if(priceBookId == null){
            priceBookId = [SELECT Id, Name, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        }

        List<Parent_Child_Product_Junction__c> parentChildJunctionList = [SELECT Id, Name, Parent_Product__c, Child_Product__c FROM Parent_Child_Product_Junction__c];

        Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id, Name, ProductCode, Description, Class__c, Family, (SELECT Id, Pricebook2Id, UnitPrice, IsActive, UseStandardPrice FROM PricebookEntries WHERE IsActive = true AND Pricebook2Id =: priceBookId AND currencyISOCode =: opp.currencyISOCode LIMIT 1) FROM Product2 WHERE IsActive = true Order by createdDate desc LIMIT 100]);

        Map<Id, List<Product2>> parentChildMap = new Map<Id, List<Product2>>();
        Set<Id> childSet = new Set<Id>();

        for (Parent_Child_Product_Junction__c junction : parentChildJunctionList) {
            childSet.add(junction.Child_Product__c);
            if (parentChildMap.containsKey(junction.Parent_Product__c)) {
                List<Product2> tempProductList = parentChildMap.get(junction.Parent_Product__c);
                tempProductList.add(productMap.get(junction.Child_Product__c));
                parentChildMap.put(junction.Parent_Product__c,tempProductList);
            } else {
                parentChildMap.put(junction.Parent_Product__c, new List<Product2>{productMap.get(junction.Child_Product__c)});
            }
        }
        
        List<dataWrapper> dataWrapperList = new List<dataWrapper>();
        for (Id productId : productMap.keySet()) {
            if (productMap.get(productId).PricebookEntries.size() > 0) {
                productWrapper productWrapp = new productWrapper();
                productWrapp.product = productMap.get(productId);
                productWrapp.pricebookEntryRec = productMap.get(productId).PricebookEntries[0];

                dataWrapper dataWrapper = new dataWrapper();
                dataWrapper.productWrap = productWrapp;
                dataWrapper.isParent = parentChildMap.containsKey(productId);
                dataWrapper.ischild = childSet.contains(productId);
                if (dataWrapper.isParent) {
                    List<productWrapper> productWrappList = new List<productWrapper>();
                    for (Product2 prod : parentChildMap.get(productId)) {
                        if (prod.PricebookEntries.size() > 0){
                            productWrapper productWrappRec = new productWrapper();
                            productWrappRec.product = prod;
                            productWrappRec.pricebookEntryRec = prod.PricebookEntries[0];
                            productWrappList.add(productWrappRec);
                        }
                    }
                    dataWrapper.childProductWrapList = productWrappList;
                }
                dataWrapperList.add(dataWrapper);
            }
        }

        return dataWrapperList;
    }

    @AuraEnabled
    public static void createOpportunityLineItem(List<OpportunityLineItem> oppLineItemList){
        	
        
        
        
        insert oppLineItemList;
    }

    public class dataWrapper {
        @AuraEnabled 
        public productWrapper productWrap {get;set;}

        @AuraEnabled 
        public Boolean isParent {get;set;}

        @AuraEnabled 
        public Boolean ischild {get;set;}

        @AuraEnabled 
        public List<productWrapper> childProductWrapList {get;set;}
    }

    public class productWrapper {
        @AuraEnabled 
        public Product2 product {get;set;}

        @AuraEnabled 
        public PricebookEntry pricebookEntryRec {get;set;}
    }
}