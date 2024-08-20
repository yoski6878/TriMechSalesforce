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
    
  /*public static void beforeUpdate(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic      
  }
    
  public static void beforeDelete(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic      
  }
    
  public static void afterInsert(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
      //Implement business logic      
  }
  
  public static void afterUpdate(List<Quote> newList,List<Quote> oldList, Map<Id,Quote> newMap, Map<Id,Quote> oldMap){
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
}