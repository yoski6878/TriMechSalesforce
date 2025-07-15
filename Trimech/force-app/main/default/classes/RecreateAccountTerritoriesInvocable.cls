global class RecreateAccountTerritoriesInvocable {

    //Changed parameter from List<List<String>> acctIds to List<String>
    @InvocableMethod
    global static void RecreateAccountTerritoriesInvocable(List<RecreateAccountTerritoresParams> params) {

        Set<Id> territories = new Set<Id>();
        for (Territory_Assignment__c ta : params[0].taList) {
            territories.add(ta.Territory__c);
        }

        List<Account_Territory__c> atList = [SELECT Id, Territory__c, Account__c FROM Account_Territory__c WHERE Territory__c IN: territories AND (Account__r.ShippingPostalCode != null) AND 
        (
         Account__r.Sales_Rep_Hardware_Inside__c = :params[0].userId 
         OR 
         Account__r.Sales_Rep_Hardware_Outside__c = :params[0].userId
         OR
         Account__r.Sales_Rep_Software__c = :params[0].userId
         OR
         Account__r.Sales_Rep_SolidCAM__c = :params[0].userId
         OR
         Account__r.Sales_Rep_Enterprise__c = :params[0].userId
        )];

/*TH-         List<Account_Territory__c> atList = [SELECT id, Territory__c, Account__c FROM Account_Territory__c WHERE Territory__c IN: territories AND (Account__r.ShippingPostalCode != null) AND 
        (
         Account__r.Sales_Rep_Hardware_Inside__c = :params[0].userId 
         OR 
         Account__r.Sales_Rep_Hardware_Outside__c = :params[0].userId
         OR
         Account__r.Sales_Rep_Software_Inside__c = :params[0].userId
         OR
         Account__r.Sales_Rep_Software_Lead_Development__c = :params[0].userId
         OR
         Account__r.Sales_Rep_Software_Outside__c = :params[0].userId
        )]; TH-*/
        /*List<Account> colAccountsToRecreateTerritories = [SELECT Id, Name FROM Account WHERE 
                               (ShippingPostalCode != null) AND 
                               (
                                Sales_Rep_Hardware_Inside__c = :params[0].userId 
                                OR 
                                Sales_Rep_Hardware_Outside__c = :params[0].userId
                                OR
                                Sales_Rep_Software_Inside__c = :params[0].userId
                                OR
                                Sales_Rep_Software_Lead_Development__c = :params[0].userId
                                OR
                                Sales_Rep_Software_Outside__c = :params[0].userId
                               ) AND (Territory__c IN: territories)]; */

        List<String> acctIds = new List<String>();
        for (Account_Territory__c at : atList) {
            acctIds.add(at.Account__c);
        }
        System.debug(acctIds);

        if (!acctIds.isEmpty()) {
            String setString = '(\'';
            //Changed acctIds[0] to acctIds
            for (String aid : acctIds) {
                setString += aid + '\',\''; 
            }
            setString = setString.left(setString.length()-2) + ')';
            System.debug('setString = ' + setString);

            RecreateAccountTerritoriesBatch b = new RecreateAccountTerritoriesBatch('SELECT ShippingPostalCode, ShippingCountry FROM Account WHERE ShippingPostalCode != NULL AND Id IN ' + setString);
            Database.executeBatch(b, 10);

        }

    }

    global class RecreateAccountTerritoresParams {
        @InvocableVariable
        global Id userId;

        @InvocableVariable
        global List<Territory_Assignment__c> taList;
    }
}