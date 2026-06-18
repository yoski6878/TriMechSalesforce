public without sharing class RecreateAccountTerritories {
    
    public static void doRecalculation(List<Account> accts){
        
        Set<Id> accIds = new Set<Id>();
        Set<Id> accWithZipsIds = new Set<Id>();
        //Set<String> zipCodes = new Set<String>();
        for(Account acct : accts){
            accIds.add(acct.Id);
        }

        Map<Id, String> acctIdToCleanZip = new Map<Id, String>();
        for (Account a : accts) {

            if(a.ShippingPostalCode != null && a.ShippingPostalCode.length() >= 5){
                if (a.ShippingCountry != null) {
                    if (a.ShippingCountry.toLowerCase() == 'us' || a.ShippingCountry.toLowerCase() == 'usa' || a.ShippingCountry.toLowerCase().contains('united states')) {
                        //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                        acctIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                    } else if (a.ShippingCountry.toLowerCase() == 'ca' || a.ShippingCountry.toLowerCase() == 'canada') {
                        //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                        acctIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    } else {
                        acctIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    }
                } else {
                    if (Pattern.matches('\\d{5}(-\\d{1,})?', a.ShippingPostalCode)) { //somewhat matches US zip code format
                        //zipCodes.add(a.ShippingPostalCode?.substring(0,5));
                        acctIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                    } else {
                        //zipCodes.add(a.ShippingPostalCode?.deleteWhitespace());
                        acctIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                    }
                }
            }

            /*if(a.ShippingPostalCode != null && a.ShippingPostalCode.length() >= 5){
                if (a.ShippingCountry.toLowerCase() == 'us' || a.ShippingCountry.toLowerCase() == 'usa' || a.ShippingCountry.toLowerCase().contains('united states')) {
                    acctIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                } else if (a.ShippingCountry.toLowerCase() == 'ca' || a.ShippingCountry.toLowerCase() == 'canada') {
                    acctIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                } else if (Pattern.matches('\\d{5}(-\\d{1,})?', a.ShippingPostalCode)) { //somewhat matches US zip code format
                    acctIdToCleanZip.put(a.id, a.ShippingPostalCode.substring(0,5));
                } else {
                    acctIdToCleanZip.put(a.id, a.ShippingPostalCode.deleteWhitespace());
                }
            }*/
        }
        
        
        delete new List<Account_Territory__c>([SELECT Id FROM Account_Territory__c WHERE Account__c IN :accIds]);

        Map<String,Territory_Zip_Code__c[]> zipToTerritories = new Map<String,Territory_Zip_Code__c[]>();
        Map<Id, Zip_Code__c> zipCodeMap = new Map<Id, Zip_Code__c>([SELECT id FROM Zip_Code__c WHERE Zip_Code_no_space__c IN :acctIdToCleanZip.values()]);

        if (zipCodeMap.size()>0) {
            for(Territory_Zip_Code__c tzc : [SELECT Id, Zip_Code_Record__r.Zip_Code_no_space__c, Territory__c FROM Territory_Zip_Code__c WHERE Zip_Code_Record__c IN :zipCodeMap.keySet()]){
                Territory_Zip_Code__c[] territoriesForThisZip = new Territory_Zip_Code__c[]{tzc};
                if(zipToTerritories.containsKey(tzc.Zip_Code_Record__r.Zip_Code_no_space__c)) territoriesForThisZip.addAll(zipToTerritories.get(tzc.Zip_Code_Record__r.Zip_Code_no_space__c));
                zipToTerritories.put(tzc.Zip_Code_Record__r.Zip_Code_no_space__c, territoriesForThisZip);
            }
        }
        
        Account_Territory__c[] newAccountTerritories = new Account_Territory__c[]{};
        for(Id aId : acctIdToCleanZip.keySet()){
            if(zipToTerritories.containsKey(acctIdToCleanZip.get(aId))){
                for(Territory_Zip_Code__c tzc : zipToTerritories.get(acctIdToCleanZip.get(aId))){
                    newAccountTerritories.add(new Account_Territory__c(Account__c = aId, Territory__c = tzc.Territory__c));    
                }
            }
        }
        
        if(!newAccountTerritories.isEmpty()) insert newAccountTerritories;
    }
}