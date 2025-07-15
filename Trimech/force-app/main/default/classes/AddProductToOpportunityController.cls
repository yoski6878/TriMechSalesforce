public without sharing class AddProductToOpportunityController {

    @AuraEnabled
    public static List<dataWrapper> getProductData(Id opportunityId, String lastPricebookEntryId, Boolean isInitialLoad, filterWrapper appliedFilters) {
        
        Opportunity opp = [SELECT Id, Name, Pricebook2Id, currencyISOCode FROM Opportunity WHERE Id =: opportunityId];
        Id priceBookId = opp.Pricebook2Id;
        Integer recordCount;
        String currencyCode = opp.currencyISOCode;
        if (priceBookId == null) {
            priceBookId = [SELECT Id, Name, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        }

        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();


        String baseQuery = 'SELECT Id, Product2Id, UnitPrice, IsActive, UseStandardPrice, Product2.Name,Product2.ProductCode,Product2.License_Type__c,Product2.Description,Product2.Client_Type__c,Product2.Network_Stand_Alone__c, Product2.Elite_Essential__c, Product2.Class__c, Product2.Family, Product2.Minimum_Quantity__c, Product2.Business_Unit__c ' + 
        'FROM PricebookEntry WHERE IsActive = true AND Pricebook2Id = :priceBookId AND currencyISOCode =: currencyCode ';


        List<Parent_Child_Product_Junction__c> junctionList = new List<Parent_Child_Product_Junction__c>();
        Set<Id> ProductTypeProductIds = new Set<Id>();
        if(appliedFilters.productType != 'All' && appliedFilters.productType != '' && appliedFilters.productType != null){

            System.debug('Inside productType if statement');

            junctionList = [SELECT Id, Parent_Product__c, Child_Product__c, Child_Product__r.Name FROM Parent_Child_Product_Junction__c];    
            for(Parent_Child_Product_Junction__c p : junctionList){
                productTypeProductIds.add(p.Parent_Product__c);
                productTypeProductIds.add(p.Child_Product__c);
            }
            baseQuery  += ' AND  Product2Id IN :productTypeProductIds ';
        }
        String searchCondition = buildQueryFilters(appliedFilters);

        List<Id> productIds = new List<Id>();

        if (appliedFilters != null && String.isNotBlank(appliedFilters.searchValue)) {


            String searchString = appliedFilters.searchValue;

            searchString = appliedFilters.searchValue + '*';

            List<List<Product2>> searchResults = [FIND :searchString IN ALL FIELDS 
                                                RETURNING Product2(Id, Name, ProductCode, Description WHERE IsActive = true )];
            if (!searchResults.isEmpty()) {
                productIds = new List<Id>();
                for (Product2 p : searchResults[0]) {
                    productIds.add(p.Id);
                }
            }
        }

        if (!productIds.isEmpty()) {
            baseQuery += ' AND Product2Id IN :productIds';
        }

        if (lastPricebookEntryId != null && lastPricebookEntryId != '') {
            baseQuery += 'AND Id > :lastPricebookEntryId ';
        }

        if (searchCondition != null && searchCondition!='' ) {
            baseQuery += searchCondition ;
        }

        if(isInitialLoad) {
            baseQuery += ' ORDER BY Id ASC LIMIT 1200';

            if (searchCondition != null) {
                String QueryString = 'SELECT Count(Id) totalRecords FROM PricebookEntry WHERE IsActive = true AND Pricebook2Id = :priceBookId AND currencyISOCode =: currencyCode' + searchCondition;
                if (!productIds.isEmpty()) {
                    QueryString += ' AND Product2Id IN :productIds';
                } 
                if (appliedFilters != null && String.isNotBlank(appliedFilters.searchValue) && productIds.isEmpty()) {
                    recordCount = 0;
                }else{
                    AggregateResult result = database.query(QueryString);
                    recordCount = (Integer) result.get('totalRecords');
                }
                System.debug('recordCount inside IF -->' + recordCount);

            }else{
                recordCount = [SELECT Count() FROM PricebookEntry WHERE IsActive = true AND Pricebook2Id = :priceBookId AND currencyISOCode =: currencyCode];
            }
        } else {
            baseQuery += ' ORDER BY Id ASC LIMIT 400';
        }

        List<PricebookEntry> pricebookEntryList = new List<PricebookEntry>();

        if (appliedFilters != null && String.isNotBlank(appliedFilters.searchValue) && productIds.isEmpty()) {
            
        }else{
            pricebookEntryList = (List<PricebookEntry>) Database.query(baseQuery);
        }
        pricebookEntryMap = new Map<Id, PricebookEntry>(pricebookEntryList);
        Map<String, PricebookEntry> productPricebookEntry = new Map<String, PricebookEntry>();
        for (PricebookEntry pbe : pricebookEntryList) {
            if (!productPricebookEntry.containsKey(pbe.Product2Id)) {
                productPricebookEntry.put(pbe.Product2Id, pbe);
            }
        }

        List<Parent_Child_Product_Junction__c> parentChildJunctionList = [SELECT Id, Name, Parent_Product__c, Child_Product__c FROM Parent_Child_Product_Junction__c where Parent_Product__c IN: productPricebookEntry.keySet() OR Child_Product__c IN: productPricebookEntry.keySet() ];
        Map<Id, List<PricebookEntry>> parentChildMap = new Map<Id, List<PricebookEntry>>();
        Set<Id> childSet = new Set<Id>();

        if(parentChildJunctionList.size()>0){
            for (Parent_Child_Product_Junction__c junction : parentChildJunctionList) {
                childSet.add(junction.Child_Product__c);
                if (parentChildMap.containsKey(junction.Parent_Product__c)) {
                    parentChildMap.get(junction.Parent_Product__c).add(productPricebookEntry.get(junction.Child_Product__c));
                } else {
                    parentChildMap.put(junction.Parent_Product__c, new List<PricebookEntry>{productPricebookEntry.get(junction.Child_Product__c)});
                }
            } 
        }

        List<dataWrapper> dataWrapperList = new List<dataWrapper>();
        for (Id pricebookEntryId : pricebookEntryMap.keySet()) {

            if (pricebookEntryMap.get(pricebookEntryId) != null) {
                productWrapper productWrap = new productWrapper();
                productWrap.pricebookEntryRec = pricebookEntryMap.get(pricebookEntryId);
                productWrap.product = pricebookEntryMap.get(pricebookEntryId).Product2;
                dataWrapper dataWrap = new dataWrapper();
                dataWrap.recordCount = recordCount;
                dataWrap.productWrap = productWrap;
                dataWrap.isParent = parentChildMap.containsKey(pricebookEntryMap.get(pricebookEntryId).Product2Id);
                dataWrap.isChild = childSet.contains(pricebookEntryMap.get(pricebookEntryId).Product2Id);

                if (dataWrap.isParent) {
                    List<productWrapper> childProductWrapList = new List<productWrapper>();
                    for (PricebookEntry childEntry : parentChildMap.get(pricebookEntryMap.get(pricebookEntryId).Product2Id)) {
                        if (childEntry != null) {
                            productWrapper childWrap = new productWrapper();
                            childWrap.pricebookEntryRec = childEntry;
                            childWrap.product = childEntry.Product2;
                            childProductWrapList.add(childWrap);
                        }
                    }
                    dataWrap.childProductWrapList = childProductWrapList;
                }
                dataWrapperList.add(dataWrap);
            }
        }
        return dataWrapperList;
    }


    public static string buildQueryFilters(filterWrapper filters) {

        String conditions  = '';

        if(filters != null) {
            // if (String.isNotBlank(filters.searchValue)) {
            //     conditions = ' AND (Product2.Name LIKE  \'%' + filters.searchValue+ '%\' OR Product2.ProductCode LIKE  \'%' + filters.searchValue+ '%\' OR  Product2.Description LIKE  \'%' + filters.searchValue+ '%\')';
            // }
            if (filters.productCode != null && filters.productCode != '') {
                conditions += ' AND Product2.ProductCode LIKE  \'%' + filters.productCode+ '%\'';
            }
            if (filters.licenseType != null && filters.licenseType.size() > 0) {
                conditions += ' AND Product2.License_Type__c IN ' + formatValues(filters.licenseType);
            }
            if (filters.clientType != null && filters.clientType.size() > 0) {
                conditions += ' AND Product2.Client_Type__c in ' + formatValues(filters.clientType);
            }
            if (filters.network != null && filters.network.size() > 0) {
                conditions += ' AND Product2.Network_Stand_Alone__c in '  + formatValues(filters.network);
            }

            if (filters.eliteEssential != null && filters.eliteEssential.size() > 0) {
                conditions += ' AND Product2.Elite_Essential__c in ' +  formatValues(filters.eliteEssential);
            }

            if (filters.productClass != null && filters.productClass.size() > 0) {
                conditions += ' AND Product2.Class__c in '+formatValues( filters.productClass);
            }
            if (filters.businessUnit != null && filters.businessUnit.size() > 0) {
                conditions += ' AND Product2.Business_Unit__c in '+formatValues( filters.businessUnit);
            }
        }
    
        return conditions;
    }

    public static String formatValues (List<String> stringList){
        String formattedValues = '(';
            
        for (Integer i = 0; i < stringList.size(); i++) {
            formattedValues += '\'' + String.escapeSingleQuotes(stringList[i]) + '\'';
            if (i < stringList.size() - 1) {
                formattedValues += ',';
            }
        }
        formattedValues += ')';

        return formattedValues;
    }

    @AuraEnabled
    public static void createOpportunityLineItem(List<OpportunityLineItem> oppLineItemList){
        insert oppLineItemList;
    }

    @AuraEnabled
    public static List<productWrapper> getRelatedChildProductData (List<Id> productIds, Id opportunityId){

        List<productWrapper> productWrapList = new List<productWrapper>();
        Set<Id> childIds = new Set<Id>();

        Opportunity opp = [SELECT Id, Name, Pricebook2Id, currencyISOCode FROM Opportunity WHERE Id =: opportunityId];
        Id priceBookId = opp.Pricebook2Id;
        Integer recordCount;
        String currencyCode = opp.currencyISOCode;
        if (priceBookId == null) {
            priceBookId = [SELECT Id, Name, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        }

        List<Parent_Child_Product_Junction__c> junctionList = new List<Parent_Child_Product_Junction__c>();
        junctionList = [SELECT Id, Parent_Product__c, Child_Product__c, Child_Product__r.Name FROM Parent_Child_Product_Junction__c WHERE Parent_Product__c IN: productIds ];  
        for(Parent_Child_Product_Junction__c productJunction : junctionList){
            childIds.add(productJunction.Child_Product__c);
        }
        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();
        String baseQuery = 'SELECT Id, Product2Id, UnitPrice, IsActive, UseStandardPrice, Product2.Name,Product2.ProductCode,Product2.License_Type__c,Product2.Description,Product2.Client_Type__c,Product2.Network_Stand_Alone__c, Product2.Elite_Essential__c, Product2.Class__c, Product2.Family, Product2.Minimum_Quantity__c, Product2.Business_Unit__c ' + 
        'FROM PricebookEntry WHERE IsActive = true AND Pricebook2Id = :priceBookId AND currencyISOCode =: currencyCode ';
        baseQuery  += ' AND  Product2Id IN :childIds';

        List<PricebookEntry> pricebookEntryList = (List<PricebookEntry>) Database.query(baseQuery);
        pricebookEntryMap = new Map<Id, PricebookEntry>(pricebookEntryList);

        for (Id pricebookEntryId : pricebookEntryMap.keySet()) {
            productWrapper productWrap = new productWrapper();
            productWrap.pricebookEntryRec = pricebookEntryMap.get(pricebookEntryId);
            productWrap.product = pricebookEntryMap.get(pricebookEntryId).Product2;
            productWrapList.add(productWrap);
        }

        return productWrapList;

    }

    public class dataWrapper {
        @AuraEnabled
        public integer recordCount {get;set;}

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

    public class filterWrapper{

        @AuraEnabled
        public String searchValue {get;set;}

        @AuraEnabled 
        public String productCode {get;set;}

        @AuraEnabled 
        public List<String> licenseType {get;set;}
        
        @AuraEnabled 
        public List<String> clientType {get;set;}

        @AuraEnabled 
        public List<String> network {get;set;}

        @AuraEnabled 
        public List<String> eliteEssential {get;set;}

        @AuraEnabled 
        public List<String> productClass {get;set;}

        @AuraEnabled 
        public List<String> businessUnit {get;set;}

        @AuraEnabled 
        public string productType {get;set;}

    }
}