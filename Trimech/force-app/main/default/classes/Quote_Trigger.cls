/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Quote object.
 *
 *********************************************************/
public without sharing class Quote_Trigger {
    
  public static void beforeInsert(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      
      for(Quote q : newList){
          q.Account__c = q.Opportunity_Account_Id__c;
      }
  }
    
    public static void afterUpdate(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
		// Logic to set values when they start sync quote line 
        Set<Id> quoteIds = new Set<Id>();
        for(Quote q : newList){
            if(q.IsSyncing && !oldMap.get(q.Id).IsSyncing){
                quoteIds.add(q.Id);
            }
        }
        
        if(quoteIds != null){
            List<QuoteLineItem> qli = [SELECT Id FROM QuoteLineItem WHERE quoteId in: quoteIds];
            if(qli != null){
                QuoteLineItem_Trigger.callFutureToUpdateOLIs(qli);
            }
        }
        
  }
    
    public static void afterInsert(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
        Quote_Trigger.storeAddressFromAccount(newList);
    }
    
  /*public static void beforeUpdate(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic      
  }
    
  public static void beforeDelete(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic      
  }
    
  
  
  
  
  public static void afterDelete(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic    
  }
  
  public static void afterUnDelete(List<Asset> newList,List<Asset> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic    
  }
  
  //helper methods
  public static void helpermethod(Set<Id> quotes) {
    
    }*/
    
    public static void storeAddressFromAccount(List<Quote> newList){
		
		Set<Id> OpportunityIds = new Set<Id>();
        for (Quote Qt : newList) {
            if (Qt.OpportunityId != null) {
                OpportunityIds.add(Qt.OpportunityId);
            }
        }
    
        // Fetch all addresses related to these accounts
        List<Schema.Address> accountAddresses = [SELECT Id, IsDeleted, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City, State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description, DrivingDirections, TimeZone, Lead_Opportunity__c, Primary_Billing_Address__c, Primary_Shipping_Address__c FROM Address WHERE Lead_Opportunity__c IN :OpportunityIds];

        // Group addresses by AccountId
        Map<Id, List<Schema.Address>> oppToAddresses = new Map<Id, List<Schema.Address>>();
        for (Schema.Address addr : accountAddresses) {
            if (!oppToAddresses.containsKey(addr.Lead_Opportunity__c)) {
                oppToAddresses.put(addr.Lead_Opportunity__c, new List<Schema.Address>());
            }
            oppToAddresses.get(addr.Lead_Opportunity__c).add(addr);
        }

        // Clone and reassign addresses to Opportunity
        List<Schema.Address> addressesToInsert = new List<Schema.Address>();
        for (Quote Qt : newList) {
            if (oppToAddresses.containsKey(Qt.OpportunityId)) {
                for (Schema.Address addr : oppToAddresses.get(Qt.OpportunityId)) {
                    Schema.Address newAddr = addr.clone();
                    newAddr.Lead_Opportunity__c = null ;
					newAddr.proposal__c = Qt.Id;
                    addressesToInsert.add(newAddr);
                }
            }
        }
        
        if (!addressesToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(addressesToInsert, false);   
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('Failed to insert address: ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }
    
}