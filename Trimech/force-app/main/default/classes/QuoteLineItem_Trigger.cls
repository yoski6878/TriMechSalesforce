/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the QuoteLineItem object.
 *
 *********************************************************/
public class QuoteLineItem_Trigger {

    //Static booleans used by trigger to limit trigger execution to once per process    
    public static Boolean hasRunBeforeInsert = false;
    public static Boolean hasRunBeforeUpdate = false;
    public static Boolean hasRunBeforeDelete = false;
    public static Boolean hasRunAfterInsert = false;
    public static Boolean hasRunAfterUpdate = false;
    public static Boolean hasRunAfterDelete = false;
    public static Boolean hasRunAfterUnDelete = false;

    public static void beforeInsert(List<QuoteLineItem> newList,List<QuoteLineItem> oldList, Map<Id,QuoteLineItem> newMap, Map<Id,QuoteLineItem> oldMap){
        Set<Id> setProduct = new Set<Id>();
        for(QuoteLineItem qli : newList){
            if(qli.Product2Id != null){ 
                setProduct.add(qli.Product2Id);
            }
        }   
        if(!setProduct.isEmpty()) setDefaultsfromProduct(newList, setProduct);   
    }
    
    

    public static void afterInsert(List<QuoteLineItem> newList){
        rollupMonths(newList);
    }
    public static void afterUpdate(List<QuoteLineItem> newList){
        rollupMonths(newList);
    }

    public static void setDefaultsfromProduct(List<QuoteLineItem> qliList, Set<Id> setProduct) {
       Map<Id, Product2> prodMap = new Map<Id, Product2>([SELECT Id, Description, CurrencyIsoCode, Purchase_Price__c, Category__c, Discount_Percent__c, Commissionable__c, Corresponding_Product_Category__c FROM Product2 WHERE Id IN :setProduct]);
        for (QuoteLineItem qli : qliList){
            if(prodMap.containsKey(qli.Product2Id)){
                /*if(qli.CurrencyIsoCode == prodMap.get(qli.Product2Id).CurrencyIsoCode){
                    qli.Product_Purchase_Price__c = prodMap.get(qli.Product2Id).Purchase_Price__c;
                }
                else if (qli.CurrencyIsoCode == 'USD'){
                    qli.Product_Purchase_Price__c = (prodMap.get(qli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateCADtoUSD) );
                }
                else if (qli.CurrencyIsoCode == 'CAD'){
                    qli.Product_Purchase_Price__c = (prodMap.get(qli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateUSDtoCAD) );
                }*/
                qli.Product_Category__c = prodMap.get(qli.Product2Id).Corresponding_Product_Category__c;
                qli.Line_Item_Description__c = prodMap.get(qli.Product2Id).Description;
                qli.Commission__c = prodMap.get(qli.Product2Id).Commissionable__c;
                qli.Vendor_Discount_Percent__c = prodMap.get(qli.Product2Id).Discount_Percent__c;
                qli.Category_Product__c = prodMap.get(qli.Product2Id).Category__c;
                 qli.Line_Item_Description__c = prodMap.get(qli.Product2Id).Description;
            }
        }
    }
    
    public static void rollupMonths(List<QuoteLineItem> triggernew){
        Set<Id> quoteIds = new Set<Id>();
        for(QuoteLineItem rec : triggernew){
            if(rec.Months__c != null){
                quoteIds.add(rec.QuoteId);
            }
        }
        
        if(!quoteIds.isEmpty()){
            List<AggregateResult> monthsQlis = new List<AggregateResult>([SELECT  SUM(Months__c) months,QuoteId FROM QuoteLineItem where quoteId in :quoteIds group by QuoteId]);
            List<Quote> quotelist = new List<Quote>();
            for(AggregateResult rec : monthsQlis){
                Quote record = new Quote();
                record.Id = String.valueOf(rec.get('QuoteId'));
                record.Total_Months__c = Integer.valueOf(rec.get('months'));
                quotelist.add(record);
            }
            
            if(!quoteList.isEmpty()){
                update quotelist;
            }
        }
    }
    
    //Added By Yoseph
    public static void updateOpportunityLineItems(List<QuoteLineItem> quoteLineItems) {
        Map<Id, QuoteLineItem> quoteLineItemMap = new Map<Id, QuoteLineItem>();
        for(QuoteLineItem qli : quoteLineItems) {
            if(qli.OpportunityLineItemId != null) {
                quoteLineItemMap.put(qli.OpportunityLineItemId, qli);
            }
        }
        
        List<OpportunityLineItem> opportunityLineItems = [SELECT Id,Vendor_Discount_Percent__c, SortOrder, Commission__c, Category_Product__c, ServiceDate,Discount,
                                                                 Discount_Amount__c, AVA_SFCLOUD__Entity_Use_Code_Line__c, Line_Description__c, Description, Product_Category__c
                                                                    FROM OpportunityLineItem WHERE Id in : quoteLineItemMap.keySet()];
        System.debug('Found ' + opportunityLineItems.size() + 'to process');
        for(OpportunityLineItem opportunityLineItem : opportunityLineItems) {
            System.debug('Processing - ' + opportunityLineItem.Line_Description__c);
            System.debug('Processing - ' + quoteLineItemMap.get(opportunityLineItem.Id).Line_Item_Description__c);
            // Map the fields
            opportunityLineItem.Vendor_Discount_Percent__c = quoteLineItemMap.get(opportunityLineItem.Id).Vendor_Discount_Percent__c;
            opportunityLineItem.SortOrder = quoteLineItemMap.get(opportunityLineItem.Id).SortOrder;
            opportunityLineItem.Commission__c = quoteLineItemMap.get(opportunityLineItem.Id).Commission__c;
            opportunityLineItem.Category_Product__c = quoteLineItemMap.get(opportunityLineItem.Id).Category_Product__c;
            opportunityLineItem.ServiceDate = quoteLineItemMap.get(opportunityLineItem.Id).ServiceDate;
            opportunityLineItem.Discount = quoteLineItemMap.get(opportunityLineItem.Id).Discount;
            opportunityLineItem.Discount_Amount__c = quoteLineItemMap.get(opportunityLineItem.Id).Discount_Amount_Display__c;
            opportunityLineItem.AVA_SFCLOUD__Entity_Use_Code_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Entity_Use_Code_Line__c;
            opportunityLineItem.Line_Description__c = quoteLineItemMap.get(opportunityLineItem.Id).Line_Item_Description__c;
            opportunityLineItem.Product_Category__c = quoteLineItemMap.get(opportunityLineItem.Id).Product_Category__c;
            opportunityLineItem.Purchase_Price__c = quoteLineItemMap.get(opportunityLineItem.Id).Product_Purchase_Price__c;
            opportunityLineItem.Quantity = quoteLineItemMap.get(opportunityLineItem.Id).Quantity;
            opportunityLineItem.UnitPrice = quoteLineItemMap.get(opportunityLineItem.Id).UnitPrice;
            opportunityLineItem.AVA_SFCLOUD__SalesTax_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__SalesTax_Line__c;
            opportunityLineItem.AVA_SFCLOUD__Sales_Tax_Details__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Sales_Tax_Details__c;
            opportunityLineItem.AVA_SFCLOUD__Sales_Tax_Rate__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Sales_Tax_Rate__c;
            opportunityLineItem.AVA_SFCLOUD__Shipping_City_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Shipping_City_Line__c;
            opportunityLineItem.AVA_SFCLOUD__Shipping_Country_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Shipping_Country_Line__c;
            opportunityLineItem.AVA_SFCLOUD__Shipping_State_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Shipping_State_Line__c;
            opportunityLineItem.AVA_SFCLOUD__Shipping_Street_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Shipping_Street_Line__c;
            opportunityLineItem.AVA_SFCLOUD__Shipping_Postal_Code_Line__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Shipping_Postal_Code_Line__c;
            OpportunityLineItem.AVA_SFCLOUD__Tax_Override__c = quoteLineItemMap.get(opportunityLineItem.Id).AVA_SFCLOUD__Tax_Override__c;
            OpportunityLineItem.TotalPrice = quoteLineItemMap.get(opportunityLineItem.Id).TotalPrice;
        }
        
        update opportunityLineItems;
    }
}