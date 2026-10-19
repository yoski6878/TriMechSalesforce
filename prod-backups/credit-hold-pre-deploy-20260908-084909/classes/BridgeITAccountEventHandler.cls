public with sharing class BridgeITAccountEventHandler {

    public static void HandleAccountUpsert(
        List<Account> newAccountList,
        List<Account> oldAccountList,
        String triggerType
    ) {
        System.debug('he llegado');
        if (newAccountList == null || newAccountList.isEmpty()) {
            return;
        }

        List<Account> createAccounts = new List<Account>();
        List<Account> editAccounts   = new List<Account>();
        Set<Id> accountIdsToQuery = new Set<Id>();

        for (Integer i = 0; i < newAccountList.size(); i++) {

            Account newAcc = newAccountList[i];
            Account oldAcc = (oldAccountList != null && oldAccountList.size() > i)
                ? oldAccountList[i]
                : null;

            if (oldAcc != null) {
                String oldNsId = String.valueOf(oldAcc.celigo_sfnsio__NetSuite_Id__c);
                String newNsId = String.valueOf(newAcc.celigo_sfnsio__NetSuite_Id__c);

                if (oldNsId != newNsId) {
                    continue;
                }
            }
            
            accountIdsToQuery.add(newAcc.Id);
            
            
        }
        Map<Id, Account> fullAccountData = new Map<Id, Account>([
            SELECT
                Id,
                celigo_sfnsio__NetSuite_Id__c,
                celigo_sfnsio__Credit_Hold__c,
                celigo_sfnsio__Credit_Limit__c,
                Credit_Hold_Status__c,
                celigo_sfnsio__Days_Overdue__c,
                Name,
                ParentId,
                Phone,
                Description,
                Fax,
                Website,
                Industry,
                Client_End_Market__c,
                Government_Classification__c,
                Direct_Indirect_Orders__c,
                Email__c,
                Dedicated_Account__c,
                Dedicated_Hardware__c,
                Inside_Sales_Dedicated_Account__c,
                Sales_Rep_Enterprise__c,
                Inactive__c,
                Territory__c,
                Region__c,
                Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Sales_Rep_Hardware__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Enterprise_Rep__r.NetSuite_Internal_Id_IO__c,
                Software_Sales_Person_NS_Id__c,
                Hardware_Sales_Person_NS_Id__c,
                Enterprise_Sales_Person_NS_Id__c,
                Subsidiary__c,
                CurrencyIsoCode,
                Client_Engagement_Rep__r.NetSuite_Internal_Id_IO__c,
                Sales_Rep_Enterprise__r.NetSuite_Internal_Id_IO__c,
                Account_Type__c,
                Type,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                BillingLatitude,
                BillingLongitude,
                BillingGeocodeAccuracy,
                ShippingStreet,
                ShippingCity,
                ShippingState,
                ShippingPostalCode,
                ShippingCountry,
                ShippingLatitude,
                ShippingLongitude,
                ShippingGeocodeAccuracy,
                MSA_Expiry_Date__c,
                MSA_on_File__c,
                Acquired_From__c,
                Dsx_Site_ID__c,
                AVA_MAPPER__Exemption_Number__c,
                External_ID__c,
                celigo_sfnsio__Skip_Export_To_NetSuite__c,
                Sales_Rep_Hardware_Outside__r.NetSuite_Internal_Id_IO__c
            FROM Account
            WHERE Id IN :accountIdsToQuery
        ]);

        List<Opportunity> completedOpportunities =  [
        SELECT Id, AccountId
        FROM Opportunity 
        WHERE AccountId IN :accountIdsToQuery 
        AND StageName = 'Send to Order Management'
        ];

        for (Id accId : accountIdsToQuery) {
            Account fullAccount = fullAccountData.get(accId);
            Boolean hasNetSuiteId = !String.isBlank(fullAccount.celigo_sfnsio__NetSuite_Id__c);
            
            Boolean existsOpportunity = false;
            for( Opportunity op : completedOpportunities) {
                if(op.AccountId == accId) {
                    existsOpportunity = true;
                    break;
                }
            }
            
            if(!hasNetSuiteId && !existsOpportunity) {
                continue;
            }
            
            // 2) Route into Create vs Edit buckets
            if (!hasNetSuiteId) {
                createAccounts.add(fullAccount);
            } else {
                editAccounts.add(fullAccount);
            }
        }
        String url = System.label.BridgeIT_Webhook_Account_Logic_App_Url;

        // === Fire CREATE webhook if needed ===
        if (!createAccounts.isEmpty()) {
            String createContent = BridgeITWebhook.jsonContent(createAccounts, null);
            BridgeITWebhook.callout(url, createContent, 'create');
        }

        // === Fire EDIT webhook if needed ===
        if (!editAccounts.isEmpty()) {
            String editContent = BridgeITWebhook.jsonContent(editAccounts, null);
            BridgeITWebhook.callout(url, editContent, 'edit');
        }
    }
}