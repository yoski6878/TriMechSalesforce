/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Contact object.
 *
 *********************************************************/
public without sharing class Contact_Trigger {
    
    public static void beforeInsert(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        //Implement business logic
    }
      
    public static void beforeUpdate(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        //Implement business logic      
    }
      
    /*public static void beforeDelete(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        //Implement business logic      
    }*/
        
    public static void afterInsert(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        
        integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 

    }
    
    public static void afterUpdate(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        
        integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 

    }
    
    /*public static void afterDelete(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){

    }
    
    public static void afterUnDelete(List<Contact> newList,List<Contact> oldList, Map<Id,Contact> newMap, Map<Id,Contact> oldMap){
        //Implement business logic      
    }*/ 
    

}