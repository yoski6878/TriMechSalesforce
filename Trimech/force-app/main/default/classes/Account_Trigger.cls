/*********************************************************
 * This class contains all of the business logic for the 
 * trigger that fires for the Account object.
 *
 *********************************************************/
public without sharing class Account_Trigger {
    
    public static void beforeInsert(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        
        for(Account a : newList){
            a.OwnerId = System.Label.Default_Account_Owner; //id for admin user
        }
        
    }
      
    public static void afterInsert(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        
        Account[] newAccountsWithZipCodes = new Account[]{};
        //Set<String> zipCodes = new Set<String>();
        Map<Id, String> accIdToCleanZip = new Map<Id, String>();
        
        Account[] newAccountsWithTeamMembers = new Account[]{};
        
        integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
        
        for(Account a : newList){
            
            if(a.ShippingPostalCode != null && a.ShippingPostalCode.length() >= 5){
                newAccountsWithZipCodes.add(a);
                if (a.ShippingCountry != null) {
                    if (a.ShippingCountry.toLowerCase() == 'us' || a.ShippingCountry.toLowerCase() == 'usa' || a.ShippingCountry.toLowerCase().contains('united states')) {
                        //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                        accIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                    } else if (a.ShippingCountry.toLowerCase() == 'ca' || a.ShippingCountry.toLowerCase() == 'canada') {
                        //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                        accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    } else {
                        accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    }
                } else {
                    if (Pattern.matches('\\d{5}(-\\d{1,})?', a.ShippingPostalCode)) { //somewhat matches US zip code format
                        //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                        accIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                    } else {
                        //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                        accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    }
                }
            }
            
            //TH-if(a.Sales_Rep_Hardware_Inside__c != null || a.Sales_Rep_Hardware_Outside__c != null || a.Sales_Rep_Software_Inside__c != null || a.Sales_Rep_Software_Outside__c != null || a.Dedicated_Sales_Rep_Software_Outside__c != null || a.Dedicated_Sales_Rep_Software_Inside__c != null || a.Dedicated_Sales_Rep_Hardware__c != null) newAccountsWithTeamMembers.add(a);
            //TH-Added below lines
            if(a.Sales_Rep_Hardware_Inside__c != null || a.Sales_Rep_Hardware_Outside__c != null || 
                    a.Sales_Rep_Software__c != null || a.Sales_Rep_SolidCAM__c != null || 
                    a.Dedicated_SolidCAM_Rep__c != null || a.Dedicated_Sales_Rep_Software__c != null || a.Dedicated_Sales_Rep_Hardware__c != null) {
                newAccountsWithTeamMembers.add(a);
            }
        }
        
        if(!newAccountsWithZipCodes.isEmpty()) {createAccountTerritoryRecords(newAccountsWithZipCodes, accIdToCleanZip);}
        if(!newAccountsWithTeamMembers.isEmpty()) {setAccountTeam(newAccountsWithTeamMembers);}
        createClientProfile(newList);
    }
    
    public static void beforeUpdate(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        //Implement business logic      
    }
      
    public static void afterUpdate(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        
        Account[] newAccountsWithZipCodes = new Account[]{};
        //Set<String> zipCodes = new Set<String>();
        Map<Id, String> accIdToCleanZip = new Map<Id, String>();
        Set<Id> accountsWithOldTerritories = new Set<Id>();
        
        Account[] newAccountsWithTeamMembers = new Account[]{};

        //integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
    
        for(Account a : newList){
            if(a.Client_Profile_Question_Count__c == oldMap.get(a.Id).Client_Profile_Question_Count__c) {
                integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
            }
            
            if(a.ShippingPostalCode != oldMap.get(a.Id).ShippingPostalCode){
                accountsWithOldTerritories.add(a.Id);

                if(a.ShippingPostalCode != null && a.ShippingPostalCode.length() >= 5){
                    newAccountsWithZipCodes.add(a);
                    if (a.ShippingCountry != null) {
                        if (a.ShippingCountry.toLowerCase() == 'us' || a.ShippingCountry.toLowerCase() == 'usa' 
                                || a.ShippingCountry.toLowerCase().contains('united states')) {
                            //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                            accIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                        } else if (a.ShippingCountry.toLowerCase() == 'ca' || a.ShippingCountry.toLowerCase() == 'canada') {
                            //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                            accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                        } else {
                            accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                        }
                    } else {
                        if (Pattern.matches('\\d{5}(-\\d{1,})?', a.ShippingPostalCode)) { //mostly matches US zip code format
                            //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                            accIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                        } else {
                            //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                            accIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                        }
                    }
                }



               /* if(a.ShippingPostalCode != null && a.ShippingPostalCode.length() >= 5){
                    newAccountsWithZipCodes.add(a);
                    if (a.ShippingCountry.toLowerCase() == 'us' || a.ShippingCountry.toLowerCase() == 'usa' || a.ShippingCountry.toLowerCase().contains('united states')) {
                        zipCodes.add(a.ShippingPostalCode.substring(0,5));
                    } else if (a.ShippingCountry.toLowerCase() == 'ca' || a.ShippingCountry.toLowerCase() == 'canada') {
                        zipCodes.add(a.ShippingPostalCode.deleteWhitespace());
                    } else if (Pattern.matches('\\d{5}(-\\d{1,})?', a.ShippingPostalCode)) { //somewhat matches US zip code format
                        zipCodes.add(a.ShippingPostalCode.substring(0,5));
                    } else {
                        zipCodes.add(a.ShippingPostalCode.deleteWhitespace());
                    }
                }*/


            }
            
            if(a.Sales_Rep_Hardware_Inside__c != oldMap.get(a.Id).Sales_Rep_Hardware_Inside__c 
                || a.Sales_Rep_Hardware_Outside__c != oldMap.get(a.Id).Sales_Rep_Hardware_Outside__c 
            /*TH-    || a.Sales_Rep_Software_Inside__c != oldMap.get(a.Id).Sales_Rep_Software_Inside__c 
                || a.Sales_Rep_Software_Outside__c != oldMap.get(a.Id).Sales_Rep_Software_Outside__c
                || a.Dedicated_Sales_Rep_Software_Outside__c != oldMap.get(a.Id).Dedicated_Sales_Rep_Software_Outside__c
                || a.Dedicated_Sales_Rep_Software_Inside__c != oldMap.get(a.Id).Dedicated_Sales_Rep_Software_Inside__c
            TH-*/
                || a.Sales_Rep_Software__c != oldMap.get(a.Id).Sales_Rep_Software__c
                || a.Dedicated_Sales_Rep_Software__c != oldMap.get(a.Id).Dedicated_Sales_Rep_Software__c
                || a.Sales_Rep_SolidCAM__c != oldMap.get(a.Id).Sales_Rep_SolidCAM__c
                || a.Dedicated_SolidCAM_Rep__c != oldMap.get(a.Id).Dedicated_SolidCAM_Rep__c
                || a.Dedicated_Sales_Rep_Hardware__c != oldMap.get(a.Id).Dedicated_Sales_Rep_Hardware__c) {
                    newAccountsWithTeamMembers.add(a);
                }
        }
        
        if(!accountsWithOldTerritories.isEmpty()) {deleteAccountTerritoryRecords(accountsWithOldTerritories);}
        if(!newAccountsWithZipCodes.isEmpty()) {createAccountTerritoryRecords(newAccountsWithZipCodes, accIdToCleanZip);}  
        if(!newAccountsWithTeamMembers.isEmpty()) {setAccountTeam(newAccountsWithTeamMembers);}
    }
    
    public static void beforeDelete(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        //Implement business logic      
    }
        
    public static void afterDelete(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        
        //TH(24-Apr-24)-Added code to update the Account Team after Duplicate Merges
        Set<Id> accountsDeletedFromMerge = new Set<Id>();
        for(Account a : oldList){
            if(a.MasterRecordId != null) { accountsDeletedFromMerge.add(a.MasterRecordId); }
        }
        System.debug('SIZE: ' + accountsDeletedFromMerge.size());
        System.debug('accountsDeletedFromMerge: ' + accountsDeletedFromMerge);

        List<Account> mergedAccountsList = new List<Account>();
        if(!accountsDeletedFromMerge.isEmpty()) {
            mergedAccountsList = new List<Account>([SELECT Id, Dedicated_Sales_Rep_Hardware__c, 
                Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c, Dedicated_Sales_Rep_Software__c, 
                Sales_Rep_Software__c, Sales_Rep_SolidCAM__c, Dedicated_SolidCAM_Rep__c FROM Account WHERE Id IN :accountsDeletedFromMerge]);
        }

        Account[] newAccountsWithTeamMembers = new Account[]{};
        if(!mergedAccountsList.isEmpty()) {
            for(Account a : mergedAccountsList){
                if(a.Sales_Rep_Hardware_Inside__c != null || a.Sales_Rep_Hardware_Outside__c != null || 
                        a.Sales_Rep_Software__c != null || a.Sales_Rep_SolidCAM__c != null || 
                        a.Dedicated_SolidCAM_Rep__c != null || a.Dedicated_Sales_Rep_Software__c != null || a.Dedicated_Sales_Rep_Hardware__c != null) {
                    newAccountsWithTeamMembers.add(a);
                }
            }
        }
        
        if(!newAccountsWithTeamMembers.isEmpty()) {setAccountTeam(newAccountsWithTeamMembers);}

    }
    
    /*public static void afterUnDelete(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
        //Implement business logic      
    }*/ 
    
    /*public static void recreateTerritoriesPostMerge(Set<Id> masterAccIds){
        System.debug('In Post Merge');
        Account[] accsWithZips = new Account[]{};
        Set<String> zips = new Set<String>();
        for(Account a : [SELECT Id, ShippingPostalCode FROM Account WHERE Id IN :masterAccIds]){
            if(a.ShippingPostalCode != null){
                if(a.ShippingPostalCode.length() >= 5){
                    accsWithZips.add(a);
                    zips.add(a.ShippingPostalCode.substring(0,5));
                }
            }
        }
        
        deleteAccountTerritoryRecords(masterAccIds);
        if(!accsWithZips.isEmpty()) createAccountTerritoryRecords(accsWithZips,zips);
    }*/
    
    public static void createClientProfile(Account[] accs){
        
		List<Question_Template__c> questionTemplates = new List<Question_Template__c>([SELECT Id, Question__c FROM Question_Template__c WHERE Active__c = true]);
        List<Client_Profile_Question__c> newCPQs = new List<Client_Profile_Question__c>();
        
        for(Account a : accs){
            for(Question_Template__c qt : questionTemplates){
                newCPQs.add(new Client_Profile_Question__c(Account__c = a.Id, Question__c = qt.Question__c, Question_Template__c = qt.Id));
            }
        }
        
        if(!newCPQs.isEmpty()) {insert newCPQs;}
    }
    
    public static void setAccountTeam(Account[] accs){
        
        delete new List<AccountTeamMember>([SELECT Id FROM AccountTeamMember WHERE AccountId IN :accs AND TeamMemberRole = 'Sales Rep']);
        
        Map<Id,User> activeUserMap = new Map<Id,User>([SELECT Id FROM User WHERE IsActive = true]);
        AccountTeamMember[] newTeamMembers = new AccountTeamMember[]{};
        for(Account a : accs){
            
            Map<Id,String> userToSalesRoles = new Map<Id,String>();
/*TH-       if(a.Dedicated_Sales_Rep_Software_Inside__c != null) {
                userToSalesRoles = buildRoleMap(userToSalesRoles, 'Dedicated Software Inside Sales', a.Dedicated_Sales_Rep_Software_Inside__c, activeUserMap.containsKey(a.Dedicated_Sales_Rep_Software_Inside__c));
            } else {
                if(a.Sales_Rep_Software_Inside__c != null) userToSalesRoles = buildRoleMap(userToSalesRoles, 'Software Inside Sales', a.Sales_Rep_Software_Inside__c, activeUserMap.containsKey(a.Sales_Rep_Software_Inside__c));
            }
            if(a.Dedicated_Sales_Rep_Software_Outside__c != null) {
                userToSalesRoles = buildRoleMap(userToSalesRoles, 'Dedicated Software Outside Sales', a.Dedicated_Sales_Rep_Software_Outside__c, activeUserMap.containsKey(a.Dedicated_Sales_Rep_Software_Outside__c));
            } else {
                if(a.Sales_Rep_Software_Outside__c != null) userToSalesRoles = buildRoleMap(userToSalesRoles, 'Software Outside Sales', a.Sales_Rep_Software_Outside__c, activeUserMap.containsKey(a.Sales_Rep_Software_Outside__c));
            } 
TH-*/
            if(a.Dedicated_Sales_Rep_Software__c != null) {
                userToSalesRoles = buildRoleMap(userToSalesRoles, 'Dedicated Software Sales', a.Dedicated_Sales_Rep_Software__c, activeUserMap.containsKey(a.Dedicated_Sales_Rep_Software__c));
            } else {
                if(a.Sales_Rep_Software__c != null) {
                    userToSalesRoles = buildRoleMap(userToSalesRoles, 'Software Sales', a.Sales_Rep_Software__c, activeUserMap.containsKey(a.Sales_Rep_Software__c));
                } 
            }
            if(a.Dedicated_SolidCAM_Rep__c != null) {
                userToSalesRoles = buildRoleMap(userToSalesRoles, 'Dedicated SolidCAM Rep', a.Dedicated_SolidCAM_Rep__c, activeUserMap.containsKey(a.Dedicated_SolidCAM_Rep__c));
            } else {
                if(a.Sales_Rep_SolidCAM__c != null) {
                    userToSalesRoles = buildRoleMap(userToSalesRoles, 'Sales Rep SolidCAM', a.Sales_Rep_SolidCAM__c, activeUserMap.containsKey(a.Sales_Rep_SolidCAM__c));
                } 
            }
            if(a.Dedicated_Sales_Rep_Hardware__c != null) {
                userToSalesRoles = buildRoleMap(userToSalesRoles, 'Dedicated Hardware Sales', a.Dedicated_Sales_Rep_Hardware__c, activeUserMap.containsKey(a.Dedicated_Sales_Rep_Hardware__c));
            } else {
                if(a.Sales_Rep_Hardware_Outside__c != null) {
                    userToSalesRoles = buildRoleMap(userToSalesRoles, 'Hardware Outside Sales', a.Sales_Rep_Hardware_Outside__c, activeUserMap.containsKey(a.Sales_Rep_Hardware_Outside__c));
                }
                if(a.Sales_Rep_Hardware_Inside__c != null) {
                    userToSalesRoles = buildRoleMap(userToSalesRoles, 'Hardware Inside Sales', a.Sales_Rep_Hardware_Inside__c, activeUserMap.containsKey(a.Sales_Rep_Hardware_Inside__c));
                }
            }
            for(Id uId : userToSalesRoles.keySet()){
                newTeamMembers.add(new AccountTeamMember(AccountId = a.Id, userId = uId, TeamMemberRole = 'Sales Rep', Sales_Role__c = userToSalesRoles.get(uId)));
            }
        }
        
        if(!newTeamMembers.isEmpty()) {insert newTeamMembers;}
    }
    
    public static Map<Id,String> buildRoleMap(Map<Id,String> roleMap, String role, Id userId, Boolean isActive){
        if(!isActive) {return roleMap;}
        if(roleMap.containsKey(userId)) {role += (';' + roleMap.get(userId));}
        roleMap.put(userId,role);
        return roleMap;
    }
    
    public static void deleteAccountTerritoryRecords(Set<Id> accIds){
        System.debug('In Delete');
        delete new List<Account_Territory__c>([SELECT Id FROM Account_Territory__c WHERE Account__c IN :accIds]);
    }
    
    public static void createAccountTerritoryRecords(Account[] accsWithZips, Map<Id, String> accIdToCleanZip) {
        System.debug('In Create');
        Map<String,Territory_Zip_Code__c[]> zipToTerritories = new Map<String,Territory_Zip_Code__c[]>();
        Map<Id, Zip_Code__c> zipCodeMap = new Map<Id, Zip_Code__c>([SELECT id FROM Zip_Code__c WHERE Zip_Code_no_space__c IN :accIdToCleanZip.values()]);

        if (zipCodeMap.size()>0) {
            for(Territory_Zip_Code__c tzc : [SELECT Id, Zip_Code_Record__r.Zip_Code_no_space__c, Territory__c FROM Territory_Zip_Code__c WHERE Zip_Code_Record__c IN :zipCodeMap.keySet()]){
                Territory_Zip_Code__c[] territoriesForThisZip = new Territory_Zip_Code__c[]{tzc};
                if(zipToTerritories.containsKey(tzc.Zip_Code_Record__r.Zip_Code_no_space__c)) {
                    territoriesForThisZip.addAll(zipToTerritories.get(tzc.Zip_Code_Record__r.Zip_Code_no_space__c));
                }
                zipToTerritories.put(tzc.Zip_Code_Record__r.Zip_Code_no_space__c, territoriesForThisZip);
            }
        }

        Account_Territory__c[] newAccountTerritories = new Account_Territory__c[]{};
        for(Account a : accsWithZips){
            String acctZip = accIdToCleanZip.get(a.id);

            if(zipToTerritories.containsKey(acctZip)){
                for(Territory_Zip_Code__c tzc : zipToTerritories.get(acctZip)){
                    newAccountTerritories.add(new Account_Territory__c(Account__c = a.Id, Territory__c = tzc.Territory__c));    
                }
            }
        }
        
        if(!newAccountTerritories.isEmpty()) {insert newAccountTerritories;}
    }
}