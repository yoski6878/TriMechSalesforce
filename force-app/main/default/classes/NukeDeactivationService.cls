public without sharing class NukeDeactivationService {
    public class Preview {
        public Integer contacts = 0;
        public Integer opportunities = 0;
        public Integer cases = 0;
        public Integer assets = 0;
        public Integer contracts = 0;
        public Integer orders = 0;
        public Integer quotes = 0;
        public Integer accountTerritories = 0;
        public Integer assetSummaries = 0;
        public Integer clientProfileQuestions = 0;

        public Integer totalRelated() {
            return contacts + opportunities + cases + assets + contracts + orders + quotes +
                accountTerritories + assetSummaries + clientProfileQuestions;
        }

        public String summary(String recordType) {
            return 'Selected ' + recordType + ' will be marked Inactive; it will NOT be deleted.\n\n' +
                'Related records to deactivate:\n' +
                'Contacts: ' + contacts + '\n' +
                'Opportunities: ' + opportunities + '\n' +
                'Cases: ' + cases + '\n' +
                'Assets: ' + assets + '\n' +
                'Contracts: ' + contracts + '\n' +
                'Orders: ' + orders + '\n' +
                'Quotes: ' + quotes + '\n' +
                'Account Territories: ' + accountTerritories + '\n' +
                'Asset Summaries: ' + assetSummaries + '\n' +
                'Client Profile Questions: ' + clientProfileQuestions + '\n\n' +
                'Total related records: ' + totalRelated();
        }
    }

    public static Preview previewAccount(Id accountId) {
        validateType(accountId, Account.SObjectType);
        Preview result = new Preview();
        result.contacts = [SELECT COUNT() FROM Contact WHERE AccountId = :accountId];
        result.opportunities = [SELECT COUNT() FROM Opportunity WHERE AccountId = :accountId];
        result.cases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId];
        result.assets = [SELECT COUNT() FROM Asset WHERE AccountId = :accountId];
        result.contracts = [SELECT COUNT() FROM Contract WHERE AccountId = :accountId];
        result.orders = [SELECT COUNT() FROM Order WHERE AccountId = :accountId];
        result.quotes = [SELECT COUNT() FROM Quote WHERE QuoteAccountId = :accountId OR AccountId = :accountId OR Account__c = :accountId];
        result.accountTerritories = [SELECT COUNT() FROM Account_Territory__c WHERE Account__c = :accountId];
        result.assetSummaries = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c = :accountId];
        result.clientProfileQuestions = [SELECT COUNT() FROM Client_Profile_Question__c WHERE Account__c = :accountId];
        return result;
    }

    public static Preview previewContact(Id contactId) {
        validateType(contactId, Contact.SObjectType);
        Preview result = new Preview();
        result.opportunities = [SELECT COUNT() FROM Opportunity WHERE ContactId = :contactId OR Primary_Contact__c = :contactId OR Scheduling_Contact__c = :contactId OR Shipping_Contact__c = :contactId OR Contact_for_Payment_AP__c = :contactId OR CLOSA_Contact__c = :contactId OR SolidProfessor_Contact__c = :contactId OR Technical_Resource__c = :contactId];
        result.cases = [SELECT COUNT() FROM Case WHERE ContactId = :contactId];
        result.assets = [SELECT COUNT() FROM Asset WHERE ContactId = :contactId OR Contact__c = :contactId OR Machine_User__c = :contactId];
        result.contracts = [SELECT COUNT() FROM Contract WHERE CustomerSignedId = :contactId];
        result.orders = [SELECT COUNT() FROM Order WHERE BillToContactId = :contactId OR CustomerAuthorizedById = :contactId OR Order_Contact__c = :contactId OR ShipToContactId = :contactId];
        result.quotes = [SELECT COUNT() FROM Quote WHERE ContactId = :contactId];
        return result;
    }

    public static void deactivateAccount(Id accountId) {
        validateType(accountId, Account.SObjectType);
        update new Account(Id = accountId, Inactive__c = true, NUKE__c = false);

        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :accountId];
        for (Contact record : contacts) record.Inactive__c = true;
        updateIfPresent(contacts);

        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE AccountId = :accountId];
        for (Opportunity record : opportunities) record.NUKE_Deactivated__c = true;
        updateIfPresent(opportunities);

        List<Case> cases = [SELECT Id FROM Case WHERE AccountId = :accountId];
        for (Case record : cases) record.NUKE_Deactivated__c = true;
        updateIfPresent(cases);

        List<Asset> assets = [SELECT Id FROM Asset WHERE AccountId = :accountId];
        for (Asset record : assets) record.Inactive__c = true;
        updateIfPresent(assets);

        List<Contract> contracts = [SELECT Id FROM Contract WHERE AccountId = :accountId];
        for (Contract record : contracts) record.NUKE_Deactivated__c = true;
        updateIfPresent(contracts);

        List<Order> orders = [SELECT Id FROM Order WHERE AccountId = :accountId];
        for (Order record : orders) record.NUKE_Deactivated__c = true;
        updateIfPresent(orders);

        List<Quote> quotes = [SELECT Id FROM Quote WHERE QuoteAccountId = :accountId OR AccountId = :accountId OR Account__c = :accountId];
        for (Quote record : quotes) record.NUKE_Deactivated__c = true;
        updateIfPresent(quotes);

        List<Account_Territory__c> territories = [SELECT Id FROM Account_Territory__c WHERE Account__c = :accountId];
        for (Account_Territory__c record : territories) record.NUKE_Deactivated__c = true;
        updateIfPresent(territories);

        List<Asset_Summary__c> summaries = [SELECT Id FROM Asset_Summary__c WHERE Account__c = :accountId];
        for (Asset_Summary__c record : summaries) record.NUKE_Deactivated__c = true;
        updateIfPresent(summaries);

        List<Client_Profile_Question__c> questions = [SELECT Id FROM Client_Profile_Question__c WHERE Account__c = :accountId];
        for (Client_Profile_Question__c record : questions) record.NUKE_Deactivated__c = true;
        updateIfPresent(questions);
    }

    public static void deactivateContact(Id contactId) {
        validateType(contactId, Contact.SObjectType);
        update new Contact(Id = contactId, Inactive__c = true, NUKE__c = false);

        List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE ContactId = :contactId OR Primary_Contact__c = :contactId OR Scheduling_Contact__c = :contactId OR Shipping_Contact__c = :contactId OR Contact_for_Payment_AP__c = :contactId OR CLOSA_Contact__c = :contactId OR SolidProfessor_Contact__c = :contactId OR Technical_Resource__c = :contactId];
        for (Opportunity record : opportunities) record.NUKE_Deactivated__c = true;
        updateIfPresent(opportunities);

        List<Case> cases = [SELECT Id FROM Case WHERE ContactId = :contactId];
        for (Case record : cases) record.NUKE_Deactivated__c = true;
        updateIfPresent(cases);

        List<Asset> assets = [SELECT Id FROM Asset WHERE ContactId = :contactId OR Contact__c = :contactId OR Machine_User__c = :contactId];
        for (Asset record : assets) record.Inactive__c = true;
        updateIfPresent(assets);

        List<Contract> contracts = [SELECT Id FROM Contract WHERE CustomerSignedId = :contactId];
        for (Contract record : contracts) record.NUKE_Deactivated__c = true;
        updateIfPresent(contracts);

        List<Order> orders = [SELECT Id FROM Order WHERE BillToContactId = :contactId OR CustomerAuthorizedById = :contactId OR Order_Contact__c = :contactId OR ShipToContactId = :contactId];
        for (Order record : orders) record.NUKE_Deactivated__c = true;
        updateIfPresent(orders);

        List<Quote> quotes = [SELECT Id FROM Quote WHERE ContactId = :contactId];
        for (Quote record : quotes) record.NUKE_Deactivated__c = true;
        updateIfPresent(quotes);
    }

    private static void validateType(Id recordId, Schema.SObjectType expectedType) {
        if (recordId == null || recordId.getSObjectType() != expectedType) {
            throw new IllegalArgumentException('A valid ' + expectedType + ' record ID is required.');
        }
    }

    private static void updateIfPresent(List<SObject> records) {
        if (!records.isEmpty()) update records;
    }
}
