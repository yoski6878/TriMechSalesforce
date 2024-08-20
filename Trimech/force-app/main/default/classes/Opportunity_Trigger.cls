/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Opportunity object.
 *
 *********************************************************/
public without sharing class Opportunity_Trigger {
    //Static booleans used by trigger to limit trigger execution to once per process    
    public static Boolean hasRunBeforeInsert = false;
    public static Boolean hasRunBeforeUpdate = false;
    public static Boolean hasRunBeforeDelete = false;
    public static Boolean hasRunAfterInsert = false;
    public static Boolean hasRunAfterUpdate = false;
    public static Boolean hasRunAfterDelete = false;
    public static Boolean hasRunAfterUnDelete = false;
    //TH-Added below line to avoid hardcoding of the Id for Opportunity Record Type on lines 27 and 56 (previously 25 and 54)
    public static final ID OPPORTUNITY_RECORD_TYPE_ID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Opportunity').getRecordTypeId();

    public static void beforeInsert(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        
        //Opportunity[] oppsWithProductGroups = new Opportunity[]{};
        //Set<Id> prodGroupIds = new Set<Id>();
        Set<Id> setAccount = new Set<Id>();
        
        for(Opportunity o : newList){
            
            if(o.StageName == 'Qualified'){ 
                o.RecordTypeId = OPPORTUNITY_RECORD_TYPE_ID;
                o.Date_Qualified__c = System.Today();
                //TH-o.Qualifier__c = UserInfo.getUserId();
                o.StageName = 'In Progress';
                setAccount.add(o.AccountId);
            }
            
            if(o.Isclosed) {o.Actual_Close_Date__c = system.Today();}
            
            /*if(o.Product_Group__c != null){
                oppsWithProductGroups.add(o);
                prodGroupIds.add(o.Product_Group__c);
            }*/
        }
        
        //if(!oppsWithProductGroups.isEmpty()) {setPricebookFromProductGroup(oppsWithProductGroups,prodGroupIds);}
        if(!setAccount.isEmpty()) {mapRepsFromAccount(newList, setAccount);}
    }
      
    public static void beforeUpdate(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        
        //Opportunity[] oppsWithProductGroups = new Opportunity[]{};
        //Set<Id> prodGroupIds = new Set<Id>();
        Set<Id> setAccount = new Set<Id>();
        
        for(Opportunity o : newList){
            
            if(o.StageName != oldMap.get(o.Id).StageName){
                if(o.StageName == 'Qualified'){
                    o.RecordTypeId = OPPORTUNITY_RECORD_TYPE_ID;
                    o.Date_Qualified__c = System.Today();
                    //TH-o.Qualifier__c = UserInfo.getUserId();
                    o.StageName = 'In Progress';
                    setAccount.add(o.AccountId);
                }
                if(o.IsClosed && o.IsClosed != oldMap.get(o.Id).IsClosed){
                    o.Actual_Close_Date__c = system.Today();
                }
            }
 
            
            /*if(o.Product_Group__c != oldMap.get(o.Id).Product_Group__c){
                if(o.Product_Group__c != null){
                    oppsWithProductGroups.add(o);
                    prodGroupIds.add(o.Product_Group__c);
                } else {o.Pricebook2Id = null;}
            }*/
        }
        
        //if(!oppsWithProductGroups.isEmpty()) {setPricebookFromProductGroup(oppsWithProductGroups,prodGroupIds);}
        if(!setAccount.isEmpty()) {mapRepsFromAccount(newList, setAccount);}
    }
      
    public static void afterInsert(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        
        //integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
        
    }
    
    public static void afterUpdate(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        
        //integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
         
    }
    
/*    public static void beforeDelete(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        //Implement business logic      
    }
        
    public static void afterDelete(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        //Implement business logic      
    }
    
    public static void afterUnDelete(List<Opportunity> newList,List<Opportunity> oldList, Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        //Implement business logic      
    }*/  
    
    //Helper methods
/*TH-    public static void mapRepsFromAccount(List<Opportunity> oppList, Set<Id> setAccount) {
        
        Map<Id, Account> aMap = new Map<Id, Account>(
            [SELECT Id, Terms__c, Sales_Rep_Software_Outside__c, Sales_Rep_Software_Inside__c, Sales_Rep_Hardware_Outside__c, 
            Sales_Rep_Hardware_Inside__c, Dedicated_Sales_Rep_Hardware__c, Dedicated_Sales_Rep_Software_Inside__c,  
            Dedicated_Sales_Rep_Software_Outside__c FROM Account WHERE Id IN :setAccount LIMIT 1]);
        for (Opportunity o : oppList){
            if(aMap.containsKey(o.AccountId)){
                o.Terms__c = aMap.get(o.AccountId).Terms__c;
                if(o.ProductGroup_Name__c == 'Software'){ 
                    if(aMap.get(o.AccountId).Dedicated_Sales_Rep_Software_Outside__c != null) {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Software_Outside__c;
                    } else {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Software_Outside__c;
                    }
                    if(aMap.get(o.AccountId).Dedicated_Sales_Rep_Software_Inside__c != null) {
                        o.Inside_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Software_Inside__c;
                    } else {
                        o.Inside_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Software_Inside__c;
                    }
                }else if(o.ProductGroup_Name__c == 'Hardware'){
                    if(aMap.get(o.AccountId).Dedicated_Sales_Rep_Hardware__c != null) {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Hardware__c;
                        o.Inside_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Hardware__c;
                    } else {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Hardware_Outside__c;
                        o.Inside_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Hardware_Inside__c;
                    }
                }
            }
        }
    }TH-*/
 
    //Helper methods
    public static void mapRepsFromAccount(List<Opportunity> oppList, Set<Id> setAccount) {
    
        Map<Id, Account> aMap = new Map<Id, Account>(
            [SELECT Id, Terms__c, Sales_Rep_Software__c, Sales_Rep_Hardware_Outside__c, Sales_Rep_Hardware_Inside__c, 
            Dedicated_Sales_Rep_Hardware__c,  Dedicated_Sales_Rep_Software__c FROM Account WHERE Id IN :setAccount LIMIT 1]);
        for (Opportunity o : oppList){
            if(aMap.containsKey(o.AccountId)){
                o.Terms__c = aMap.get(o.AccountId).Terms__c;
                if(o.ProductGroup_Name__c == 'Software'){ 
                    if(aMap.get(o.AccountId).Dedicated_Sales_Rep_Software__c != null) {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Software__c;
                    } else {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Software__c;
                    }
                } else if(o.ProductGroup_Name__c == 'Hardware'){
                    if(aMap.get(o.AccountId).Dedicated_Sales_Rep_Hardware__c != null) {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Dedicated_Sales_Rep_Hardware__c;
                    } else {
                        o.Territory_Sales_Rep__c = aMap.get(o.AccountId).Sales_Rep_Hardware_Outside__c;
                    }
                }
            }
        }
    }

    /*public static void setPricebookFromProductGroup(Opportunity[] opps, Set<Id> prodGroupIds) {
        
        Map<Id,Product_Group__c> prodGroupMap = new Map<Id,Product_Group__c>([SELECT Id, Default_Price_Book__c FROM Product_Group__c WHERE Id IN :prodGroupIds]);
        for(Opportunity o : opps){
            if(prodGroupMap.containsKey(o.Product_Group__c)) {
                o.Pricebook2Id = prodGroupMap.get(o.Product_Group__c).Default_Price_Book__c;
            } else {o.Pricebook2Id = null;}
        }    
    }*/
}