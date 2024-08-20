/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the OpportunityLineItem object.
 *
 *********************************************************/

public class Product_Trigger {
    //Static booleans used by trigger to limit trigger execution to once per process    
    public static Boolean hasRunBeforeInsert = false;
    public static Boolean hasRunBeforeUpdate = false;
    public static Boolean hasRunBeforeDelete = false;
    public static Boolean hasRunAfterInsert = false;
    public static Boolean hasRunAfterUpdate = false;
    public static Boolean hasRunAfterDelete = false;
    public static Boolean hasRunAfterUnDelete = false;
    
	public static void beforeUpdate(List<Product2> newList,Map<Id,Product2> oldMap){
       	
		Set<Id> productIds = new Set<Id>();
        
        for(Product2 inx: newList){
            if(!inx.Unit_of_Measure__c && oldMap.get(inx.Id).Unit_of_Measure__c){
				productIds.add(inx.Id);
            }
        }
        
        if(!productIds.isEmpty()){
            List<OpportunityLineItem> oliList = [Select Id, Duration__c from OpportunityLineItem where Product2Id IN: productIds ];
            For(OpportunityLineItem oli : oliList){
                oli.Duration__c = null;
                oli.ByPassValidationRule__c = true;
            }
            update oliList;
            
            For(OpportunityLineItem oli : oliList){
                oli.ByPassValidationRule__c = false;
            }
            update oliList;
            
        }
        

    }    
    
    

}