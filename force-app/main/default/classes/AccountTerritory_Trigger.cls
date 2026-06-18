/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the AccountTerritory object.
 *
 *********************************************************/
public without sharing class AccountTerritory_Trigger {
    
    public static void beforeInsert(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        //Implement business logic
    }
      
    public static void afterInsert(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        
        Account_Territory__c[] newATs = new Account_Territory__c[]{};
        Set<Id> accIds = new Set<Id>();
        Set<Id> terrIds = new Set<Id>();
        
        //Set<Id> accountsWithNewPrimaryAccountTerritories = new Set<Id>();
        
        for(Account_Territory__c at : newList){
            if(at.Account__c != null && at.Territory__c != null){
                newATs.add(at);
                accIds.add(at.Account__c);
                terrIds.add(at.Territory__c);
                
                //if(at.Primary_Account_Territory__c) accountsWithNewPrimaryAccountTerritories.add(at.Account__c);
            }
        }
        
        //if(!newATs.isEmpty()) setTerritoryAssignments(newATs,accIds,terrIds);
        //if(!accountsWithNewPrimaryAccountTerritories.isEmpty()) setTerritoryAndRegionOnAccount(accountsWithNewPrimaryAccountTerritories);

        if(!newATs.isEmpty()) setTerritoryInfoOnAccounts(newATs,accIds,terrIds);
    }
    
    /*public static void beforeUpdate(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        //Implement business logic      
    }
      
    public static void afterUpdate(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        //Implement business logic  
    }*/
    
    public static void beforeDelete(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        //Implement business logic      
    }
        
    public static void afterDelete(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        
        Account_Territory__c[] delATs = new Account_Territory__c[]{};
        Set<Id> accIds = new Set<Id>();
        Set<Id> terrIds = new Set<Id>();
        
        Set<Id> accountsWithDeletedPrimaryAccountTerritories = new Set<Id>();
        
        for(Account_Territory__c at : oldList){
            if(at.Account__c != null && at.Territory__c != null){
                delATs.add(at);
                accIds.add(at.Account__c);
                terrIds.add(at.Territory__c);
                
                if(at.Primary_Account_Territory__c) accountsWithDeletedPrimaryAccountTerritories.add(at.Account__c);
            }
        }
        
        if(!delATs.isEmpty()) clearProductGroupFieldAssignments(delATs,accIds,terrIds); 
        if(!accountsWithDeletedPrimaryAccountTerritories.isEmpty()) setTerritoryAndRegionOnAccount(accountsWithDeletedPrimaryAccountTerritories);
    }
    
    /*public static void afterUnDelete(List<Account_Territory__c> newList,List<Account_Territory__c> oldList, Map<Id,Account_Territory__c> newMap, Map<Id,Account_Territory__c> oldMap){
        //Implement business logic      
    }*/ 
    
    
    
    //Helper methods
    public static void clearProductGroupFieldAssignments(Account_Territory__c[] delAccTerrs, Set<Id> accIds, Set<Id> terrIds){
        
        Set<Id> productGroupIds = new Set<Id>();
        Map<Id,Territory__c> terrMap = new Map<Id,Territory__c>();
        for(Territory__c t : [SELECT Id, Product_Group__c FROM Territory__c WHERE Id IN :terrIds AND Product_Group__c != null]){
            productGroupIds.add(t.Product_Group__c);    
            terrMap.put(t.Id,t);
        }
        
        Map<Id,Account> accMap = new Map<Id,Account>([SELECT Id FROM Account WHERE Id IN :accIds]);
        Map<Id,Product_Group__c> pgMap = new Map<Id,Product_Group__c>([SELECT Id, (SELECT Id, Account_Field_API_Name__c FROM Product_Group_Field_Assignments__r WHERE Account_Field_API_Name__c != null) FROM Product_Group__c WHERE Id IN :productGroupIds]);
        
        for(Account_Territory__c at : delAccTerrs){
            try{
                if(accMap.containsKey(at.Account__c) && terrMap.containsKey(at.Territory__c)){
                    if(pgMap.containsKey(terrMap.get(at.Territory__c).Product_Group__c)){
                        for(Product_Group_Field_Assignment__c pgfa : pgMap.get(terrMap.get(at.Territory__c).Product_Group__c).Product_Group_Field_Assignments__r){
                            accMap.get(at.Account__c).put(pgfa.Account_Field_API_Name__c,null);
                        }    
                    }
                }       
            }catch(Exception e){}
        }
        
        if(!accMap.isEmpty()) update accMap.values();
    }
    
    /*public static void setTerritoryAssignments(Account_Territory__c[] newAccTerrs, Set<Id> accIds, Set<Id> terrIds) {
        
        Map<Id,Account> accMap = new Map<Id,Account>([SELECT Id, Inside_Sales_Dedicated_Account__c, Dedicated_Hardware__c, Dedicated_Account__c FROM Account WHERE Id IN :accIds]);
        Map<Id,Territory__c> terrMap = new Map<Id,Territory__c>([SELECT Id, (SELECT Id, Account_Field_to_Assign__c, Account_Dedicated_field_to_reference__c, Assigned_User__c FROM Territory_Assignments__r) FROM Territory__c WHERE Id IN :terrIds]);
        
        
        for(Account_Territory__c at : newAccTerrs){
            try{
                if(accMap.containsKey(at.Account__c) && terrMap.containsKey(at.Territory__c)){
                    for(Territory_Assignment__c ta : terrMap.get(at.Territory__c).Territory_Assignments__r){
                        if(ta.Account_Dedicated_field_to_reference__c == null) accMap.get(at.Account__c).put(ta.Account_Field_to_Assign__c,ta.Assigned_User__c);
                        else if(!(Boolean)accMap.get(at.Account__c).get(ta.Account_Dedicated_field_to_reference__c)) accMap.get(at.Account__c).put(ta.Account_Field_to_Assign__c,ta.Assigned_User__c);
                    }
                }
            }catch(Exception e){}
        }
        
        //if(!accMap.isEmpty()) update accMap.values();
        if(!accMap.isEmpty()) {
            UpdateAccountQueueable q = new UpdateAccountQueueable(accMap.values());
            System.enqueueJob(q);        
        }
    }*/

    public static void setTerritoryAndRegionOnAccount(Set<Id> accIds){
        
        Account[] accountsToUpdate = new Account[]{};
        for(Account a : [SELECT Id, Territory__c, Region__c, Primary_Territory__c, (SELECT Id, Territory__r.Id, Territory__r.Name, Region__c FROM Account_Territories__r WHERE Primary_Account_Territory__c = true ORDER BY CreatedDate DESC LIMIT 1) FROM Account WHERE Id IN :accIds]){
            if(a.Account_Territories__r.isEmpty()) accountsToUpdate.add(new Account(Id = a.Id, Territory__c = null, Region__c = null, Primary_Territory__c = null));
            else accountsToUpdate.add(new Account(Id = a.Id, Territory__c = a.Account_Territories__r[0].Territory__r.Name, Region__c = a.Account_Territories__r[0].Region__c, Primary_Territory__c = a.Account_Territories__r[0].Territory__r.Id));
        }
        
        //if(!accountsToUpdate.isEmpty()) update accountsToUpdate;
        if(!accountsToUpdate.isEmpty()) {
            If (!System.isBatch()) {
                UpdateAccountQueueable q = new UpdateAccountQueueable(accountsToUpdate);
                System.enqueueJob(q); 
            } else {
                update accountsToUpdate;
            }       
        }
       
        
    }

    public static void setTerritoryInfoOnAccounts(Account_Territory__c[] newAccTerrs, Set<Id> accIds, Set<Id> terrIds) {

        Map<Id, Account> allAccMap = new Map<Id,Account>([SELECT Id, Territory__c, Region__c, Primary_Territory__c, Inside_Sales_Dedicated_Account__c, Dedicated_Hardware__c, Dedicated_Account__c, (SELECT Id, Territory__r.Id, Territory__r.Name, Region__c FROM Account_Territories__r WHERE Primary_Account_Territory__c = true ORDER BY CreatedDate DESC LIMIT 1) FROM Account WHERE Id IN :accIds]);
        Map<Id, Territory__c> terrMap = new Map<Id,Territory__c>([SELECT Id, (SELECT Id, Account_Field_to_Assign__c, Account_Dedicated_field_to_reference__c, Assigned_User__c FROM Territory_Assignments__r) FROM Territory__c WHERE Id IN :terrIds]);
        Map<Id, Account> accsToUpdate = new Map<Id, Account>();
        Set<Id> accountsWithNewPrimaryAccountTerritories = new Set<Id>();

        //set territory assignments
        for (Account_Territory__c at : newAccTerrs){
            if(at.Primary_Account_Territory__c) accountsWithNewPrimaryAccountTerritories.add(at.Account__c);
            try {
                if (allAccMap.containsKey(at.Account__c) && terrMap.containsKey(at.Territory__c)){
                    for (Territory_Assignment__c ta : terrMap.get(at.Territory__c).Territory_Assignments__r){
                        System.debug('AccountTerritory_Trigger.setTerritoryInfoOnAccounts: ta.Account_Field_to_Assign__c = ' + ta.Account_Field_to_Assign__c);
                        SObject so = Schema.getGlobalDescribe().get('Account').newSObject();
                        System.debug(so.getSobjectType().getDescribe().fields.getMap().containsKey(ta.Account_Field_to_Assign__c));
                        if (so.getSobjectType().getDescribe().fields.getMap().containsKey(ta.Account_Field_to_Assign__c)) {
                            System.debug('AccountTerritory_Trigger.setTerritoryInfoOnAccounts: field is a real field!');
                            //if (ta.Account_Dedicated_field_to_reference__c == null) {
                                Account tempAcct = allAccMap.get(at.Account__c);
                                tempAcct.put(ta.Account_Field_to_Assign__c,ta.Assigned_User__c);
                                accsToUpdate.put(tempAcct.id, tempAcct);
                            //} else if (!(Boolean)allAccMap.get(at.Account__c).get(ta.Account_Dedicated_field_to_reference__c)) {
                            //    Account tempAcct = allAccMap.get(at.Account__c);
                            //    tempAcct.put(ta.Account_Field_to_Assign__c,ta.Assigned_User__c);
                            //    accsToUpdate.put(tempAcct.id, tempAcct);
                            //}
                        }
                    }
                }
            } catch (Exception e){}
        }

        //set territory and region fields
        for(Account a : allAccMap.values()){
            if (accountsWithNewPrimaryAccountTerritories.contains(a.id)) {
                if(a.Account_Territories__r.isEmpty()) {
                    if (accsToUpdate.containsKey(a.id)) {
                        Account tempAcct = accsToUpdate.get(a.id);
                        tempAcct.Territory__c = null;
                        tempAcct.Region__c = null; 
                        tempAcct.Primary_Territory__c = null;
                        accsToUpdate.put(a.id, tempAcct);
                    } else {
                        accsToUpdate.put(a.id, new Account(Id = a.Id, Territory__c = null, Region__c = null, Primary_Territory__c = null));
                    }
                } else {
                    if (accsToUpdate.containsKey(a.id)) {
                        Account tempAcct = accsToUpdate.get(a.id);
                        tempAcct.Territory__c = a.Account_Territories__r[0].Territory__r.Name;
                        tempAcct.Region__c = a.Account_Territories__r[0].Region__c; 
                        tempAcct.Primary_Territory__c = a.Account_Territories__r[0].Territory__r.Id;
                        accsToUpdate.put(a.id, tempAcct);
                    } else {
                        accsToUpdate.put(a.id, new Account(Id = a.Id, Territory__c = a.Account_Territories__r[0].Territory__r.Name, Region__c = a.Account_Territories__r[0].Region__c, Primary_Territory__c = a.Account_Territories__r[0].Territory__r.Id));
                    }
                }
            }
        }
        
        if(!accsToUpdate.isEmpty()) {
            If (!System.isBatch()) {
                UpdateAccountQueueable q = new UpdateAccountQueueable(accsToUpdate.values());
                System.enqueueJob(q); 
            } else {
                update accsToUpdate.values();
            }
       
        }

    }
}