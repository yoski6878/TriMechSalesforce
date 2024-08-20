/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the OpportunityLineItem object.
 *
 *********************************************************/
public class OpportunityLineItem_Trigger {
    //Static booleans used by trigger to limit trigger execution to once per process    
    public static Boolean hasRunBeforeInsert = false;
    public static Boolean hasRunBeforeUpdate = false;
    public static Boolean hasRunBeforeDelete = false;
    public static Boolean hasRunAfterInsert = false;
    public static Boolean hasRunAfterUpdate = false;
    public static Boolean hasRunAfterDelete = false;
    public static Boolean hasRunAfterUnDelete = false;

    public static void beforeInsert(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){

        Set<Id> setProduct = new Set<Id>();
        Set<Id> setPBE = new Set<Id>();

        
        // Set the sort order
        if (!newList.isEmpty()) {
            Id opportunityId = newList[0].OpportunityId;
            Integer nextSortOrder = 1;
            List<OpportunityLineItem> res = [SELECT Id,SortOrder,Name FROM OpportunityLineItem WHERE OpportunityId = :opportunityId];
            if (!res.isEmpty()) {
                
                // Make sure that the SortOrders in the current list are sequential, starting at 1
                List<Integer> usedNumbers = new List<Integer>();
                for (OpportunityLineItem oli : res) {
                    // System.debug(oli);
                    if (oli.SortOrder != null) usedNumbers.add(oli.SortOrder);
                }

                if (!usedNumbers.isEmpty()) {

                    usedNumbers.sort();

                    // If the sort ordering starts at zero, as it does after running Lightning Sort, add 1 to each of the counters
                    if (usedNumbers[0] == 0) {
                        for (OpportunityLineItem oli : res) {
                            if (oli.SortOrder != null) {
                                oli.SortOrder = oli.SortOrder + 1;
                                update oli;
                            }
                        }
                        List<Integer> copyNumbers = new List<Integer>();
                        for (Integer usedNumber : usedNumbers) {
                                copyNumbers.add(usedNumber + 1);
                        }
                        usedNumbers.clear();
                        usedNumbers.addAll(copyNumbers);
                    }

                    for (Integer usedNumber : usedNumbers) {
                        for (OpportunityLineItem oli : res) {
                            if (oli.SortOrder != null && oli.SortOrder == usedNumber) {
                                if (usedNumber != nextSortOrder) {
                                    oli.SortOrder = nextSortOrder;
                                    update oli;
                                }
                                nextSortOrder = nextSortOrder + 1;
                            }
                        }
                    }
                }

                // Set any null SortOrders in the current list
                for (OpportunityLineItem oli : res) {
                    if (oli.SortOrder == null || String.valueOf(oli.SortOrder).trim() == '') {
                        oli.SortOrder = nextSortOrder;
                        update oli;
                        nextSortOrder = nextSortOrder + 1;
                    }
                }
            }

            // Set the SortOrders for the added items
            for(OpportunityLineItem oli : newList){
                oli.SortOrder = nextSortOrder;
                nextSortOrder = nextSortOrder + 1;
            }
        }

        for(OpportunityLineItem oli : newList){
            if(oli.Product2Id != null){ 
				setProduct.add(oli.Product2Id);
            }
            
            if(oli.PricebookEntryId != null){ 
                setPBE.add(oli.PricebookEntryId);
            }

        }
        
        if(!setProduct.isEmpty()) setDefaultsfromProduct(newList, setProduct, setPBE);   
    

    }
      
    /*public static void beforeUpdate(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        

    }*/
      
    public static void afterInsert(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        // for(OpportunityLineItem oli : newList){
        //     List<OpportunityLineItem> res = [SELECT Id,SortOrder,Description,Name FROM OpportunityLineItem WHERE OpportunityId = :oli.OpportunityId];
        //     for(OpportunityLineItem oli2 : res){
        //         System.debug(oli2);
        //     }
        // }
    }
    
    /*public static void afterUpdate(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        
         
    }*/
    
    /*public static void beforeDelete(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        //Implement business logic      
    }
        
    public static void afterDelete(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        //Implement business logic      
    }
    
    public static void afterUnDelete(List<OpportunityLineItem> newList,List<OpportunityLineItem> oldList, Map<Id,OpportunityLineItem> newMap, Map<Id,OpportunityLineItem> oldMap){
        //Implement business logic      
    }*/  
    
    //Helper methods
    public static void setDefaultsfromProduct(List<OpportunityLineItem> oliList, Set<Id> setProduct, Set<Id> setPBE) {
        
//        Nov-29-2021(TinaH): Removed the words "LIMIT 1" from below line.
//        Map<Id, Product2> prodMap = new Map<Id, Product2>([SELECT Id, Description, Purchase_Price__c, Category__c, Discount_Percent__c, Commissionable__c, Corresponding_Product_Category__c FROM Product2 WHERE Id IN :setProduct LIMIT 1]);
		Map<Id, Product2> prodMap = new Map<Id, Product2>([SELECT Id, Description, CurrencyIsoCode, Purchase_Price__c, Category__c, Discount_Percent__c, Commissionable__c, Corresponding_Product_Category__c, celigo_sfnsio__NetSuite_item_type__c FROM Product2 WHERE Id IN :setProduct]);
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>([SELECT Id, Purchase_Price__c FROM PricebookEntry WHERE Id IN :setPBE]);
        for (OpportunityLineItem oli : oliList){
            if(prodMap.containsKey(oli.Product2Id)){
                //Dec-23-2021(TinaH): Added the code to auto-calculate Purchase Price based on Opportunity Currency and Product Currency values
                //Mar-21-2024(EustaceConsulting): commented out because purchase price will come from pricebook entry
                /*if(oli.CurrencyIsoCode == prodMap.get(oli.Product2Id).CurrencyIsoCode){
                    oli.Purchase_Price__c = prodMap.get(oli.Product2Id).Purchase_Price__c;
                }
                else if (oli.CurrencyIsoCode == 'USD'){
                    oli.Purchase_Price__c = (prodMap.get(oli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateCADtoUSD) );
                }
                else if (oli.CurrencyIsoCode == 'CAD'){
                    oli.Purchase_Price__c = (prodMap.get(oli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateUSDtoCAD) );
                }*/
                    
                oli.Product_Category__c = prodMap.get(oli.Product2Id).Corresponding_Product_Category__c;
                oli.Line_Description__c = prodMap.get(oli.Product2Id).Description;
                oli.Commission__c = prodMap.get(oli.Product2Id).Commissionable__c;
                oli.Vendor_Discount_Percent__c = prodMap.get(oli.Product2Id).Discount_Percent__c;
                
                //Nov-24-2021(TinaH): Added the assignment for Category_Product__c field to pull the Category of the Product selected
                oli.Category_Product__c = prodMap.get(oli.Product2Id).Category__c;
                
                //Dec-27-2022(TinaH): Added the assignment for Product_Item_Type__c field to pull the NetSuite Item Type of the Product selected
                oli.Product_Item_Type__c = prodMap.get(oli.Product2Id).celigo_sfnsio__NetSuite_item_type__c;
                
            }
            //Mar-21-2024(EustaceConsulting): pullihg purchase price from pricebook entry
            if(pbeMap.containsKey(oli.PricebookEntryId)){
                oli.Purchase_Price__c = pbeMap.get(oli.PricebookEntryId).Purchase_Price__c;
            }
        }
    }
    

}