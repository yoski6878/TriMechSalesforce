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
    //YK - Added as part of - 729 Hardware Neglected Lead Requirements
	public static final ID LEAD_RECORD_TYPE_ID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Lead').getRecordTypeId();

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
			
            Opportunity oldRec = oldMap.get(o.Id);
            
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
            
            //YK - Added as part of - 729 Hardware Neglected Lead Requirements
            if (o.StageName == 'Neglected' && oldRec.StageName != 'Neglected') {
                o.Neglected_Date__c = Date.today();
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
		Opportunity_Trigger.storeAddressFromAccount(newList);
        
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
    
    public static void storeAddressFromAccount(List<Opportunity> oppList){
		
		Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : oppList) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
    
        // Fetch all addresses related to these accounts
        List<Schema.Address> accountAddresses = [SELECT Id, IsDeleted, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City, State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description, DrivingDirections, TimeZone, Account__c, Primary_Billing_Address__c, Primary_Shipping_Address__c FROM Address WHERE Account__c IN :accountIds];

        // Group addresses by AccountId
        Map<Id, List<Schema.Address>> accountToAddresses = new Map<Id, List<Schema.Address>>();
        for (Schema.Address addr : accountAddresses) {
            if (!accountToAddresses.containsKey(addr.Account__c)) {
                accountToAddresses.put(addr.Account__c, new List<Schema.Address>());
            }
            accountToAddresses.get(addr.Account__c).add(addr);
        }

        // Clone and reassign addresses to Opportunity
        List<Schema.Address> addressesToInsert = new List<Schema.Address>();
        for (Opportunity opp : oppList) {
            if (accountToAddresses.containsKey(opp.AccountId)) {
                for (Schema.Address addr : accountToAddresses.get(opp.AccountId)) {
                    Schema.Address newAddr = addr.clone();
                    newAddr.Account__c = null;
					newAddr.Lead_Opportunity__c = opp.Id;
                    addressesToInsert.add(newAddr);
                }
            }
        }
        
        if (!addressesToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(addressesToInsert, false);   
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    // Optional: Log or handle the failed insert
                    System.debug('Failed to insert address: ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }
}