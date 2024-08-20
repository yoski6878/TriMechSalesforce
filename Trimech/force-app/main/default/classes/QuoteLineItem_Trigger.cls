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
        /*Set<Id> setProduct = new Set<Id>();
        for(QuoteLineItem qli : newList){
            if(qli.Product2Id != null){ 
                setProduct.add(qli.Product2Id);
            }
        }   
        if(!setProduct.isEmpty()) setDefaultsfromProduct(newList, setProduct);   */
    }

    //public static void afterInsert(List<QuoteLineItem> newList,List<QuoteLineItem> oldList, Map<Id,QuoteLineItem> newMap, Map<Id,QuoteLineItem> oldMap){
    //}

    /*public static void setDefaultsfromProduct(List<QuoteLineItem> qliList, Set<Id> setProduct) {
       Map<Id, Product2> prodMap = new Map<Id, Product2>([SELECT Id, Description, CurrencyIsoCode, Purchase_Price__c, Category__c, Discount_Percent__c, Commissionable__c, Corresponding_Product_Category__c FROM Product2 WHERE Id IN :setProduct]);
        for (QuoteLineItem qli : qliList){
            if(prodMap.containsKey(qli.Product2Id)){
                if(qli.CurrencyIsoCode == prodMap.get(qli.Product2Id).CurrencyIsoCode){
                    qli.Product_Purchase_Price__c = prodMap.get(qli.Product2Id).Purchase_Price__c;
                }
                else if (qli.CurrencyIsoCode == 'USD'){
                    qli.Product_Purchase_Price__c = (prodMap.get(qli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateCADtoUSD) );
                }
                else if (qli.CurrencyIsoCode == 'CAD'){
                    qli.Product_Purchase_Price__c = (prodMap.get(qli.Product2Id).Purchase_Price__c * Decimal.valueOf(System.Label.ExchangeRateUSDtoCAD) );
                }
                qli.Product_Category__c = prodMap.get(qli.Product2Id).Corresponding_Product_Category__c;
                qli.Line_Item_Description__c = prodMap.get(qli.Product2Id).Description;
                qli.Commission__c = prodMap.get(qli.Product2Id).Commissionable__c;
                qli.Vendor_Discount_Percent__c = prodMap.get(qli.Product2Id).Discount_Percent__c;
                qli.Category_Product__c = prodMap.get(qli.Product2Id).Category__c;
            }
        }
    }*/
}