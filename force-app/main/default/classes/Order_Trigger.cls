/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Order object.
 *
 *********************************************************/
public without sharing class Order_Trigger {
    
  public static void beforeInsert(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
        
  }
    
  public static void afterInsert(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
    
      /*  Set<Id> oppIds = new Set<Id>();
        
        for(Order o : newList){
            if(o.Draft__c == 'No'){
                if(o.OpportunityId != null) oppIds.add(o.OpportunityId);
            }
        }
        
        if(!oppIds.isEmpty()) setOpportunityStage(oppIds);
      */
  }
  
  public static void beforeUpdate(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
   
  }
    
  public static void afterUpdate(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
    
        /* Set<Id> oppIds = new Set<Id>();
        
        for(Order o : newList){
            if(o.Draft__c != oldMap.get(o.Id).Draft__c && o.Draft__c == 'No'){
                if(o.OpportunityId != null) oppIds.add(o.OpportunityId);
            }
        }
        
        if(!oppIds.isEmpty()) setOpportunityStage(oppIds);
		*/
  }
  
  /*public static void beforeDelete(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
      //Implement business logic      
  }
    
  public static void afterDelete(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
      //Implement business logic

  }
  
  public static void afterUnDelete(List<Order> newList,List<Order> oldList, Map<Id,Order> newMap, Map<Id,Order> oldMap){
      //Implement business logic    
  }*/  
    
  //Helper methods
/*    
  public static void setOpportunityStage(Set<Id> oppIds) {
        
        Opportunity[] oppsToUpdate = new Opportunity[]{};
        
        for(Opportunity o : [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]){
            oppsToUpdate.add(new Opportunity(Id = o.Id, StageName = 'Closed Won'));
        }
        
        if(!oppsToUpdate.isEmpty()) update oppsToUpdate;
  }
*/
}