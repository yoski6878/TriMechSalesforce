public without sharing class NukeDeactivationService {
    public static final String ACTION_INACTIVATED = 'Inactivated';
    public static final String ACTION_DELETED = 'Deleted';

    public static final String REASON_RECENT_ACTIVITY = 'Activity in the last 12 months';
    public static final String REASON_RECENT_SURVEY = 'Survey in the last 12 months';
    public static final String REASON_RECENT_ORDER = 'On an Order less than 8 years old';
    public static final String REASON_ORDER_BLOCKS_DELETE = 'Bill To / Ship To / Authorized By contact on an Order (Salesforce does not allow deleting)';
    public static final String REASON_ADOBE_SIGN = 'Recipient on an Adobe Sign agreement';
    public static final String REASON_NO_ACTIVITY = 'No activity in the last 12 months';
    public static final String REASON_LIST_MISMATCH = 'Could not safely remove from Order Management contact lists';
    public static final String REASON_CLEANUP_FAILED = 'Cleanup before delete failed';
    public static final String REASON_DELETE_FAILED = 'Delete failed';

    private static final Integer MAX_DELETE_ATTEMPTS = 3;

    // Order Management multi-select contacts are stored on Opportunity as parallel text lists, e.g. [id1,id2] / [Name1,Name2] / [ns1,ns2].
    // Fields are resolved at runtime so a list that does not exist in the org is skipped.
    private static final List<List<String>> OPPORTUNITY_CONTACT_LISTS = new List<List<String>>{
        new List<String>{ 'End_User_Ids__c', 'End_User_Names__c', 'End_User_Netsuite_Ids__c' },
        new List<String>{ 'End_User_Ids_hardware__c', 'End_User_Names_hardware__c', 'End_User_Netsuite_Ids_hardware__c' },
        new List<String>{ 'Student_Ids__c', 'Student_Names__c', 'Student_Netsuite_Ids__c' },
        new List<String>{ 'Passport_Owner_Ids__c', 'Passport_Owner_Names__c', 'Passport_Owner_Netsuite_Ids__c' },
        new List<String>{ 'License_Key_Contact_Ids__c', 'License_Key_Contact_Names__c', 'License_Key_Contact_Netsuite_Ids__c' }
    };

    public class Preview {
        public Integer contacts = 0;
        public Integer opportunities = 0;
        public Integer cases = 0;
        public Integer assets = 0;
        public Integer orders = 0;
        public Integer quotes = 0;
        public Integer accountTerritories = 0;
        public Integer assetSummaries = 0;
        public Integer clientProfileQuestions = 0;

        public Integer totalRelated() {
            return contacts + opportunities + cases + assets + orders + quotes +
                accountTerritories + assetSummaries + clientProfileQuestions;
        }

        public String summary(String recordType) {
            return 'Selected ' + recordType + ' will be marked Inactive; it will NOT be deleted.\n\n' +
                'Related records to deactivate:\n' +
                'Contacts: ' + contacts + '\n' +
                'Opportunities: ' + opportunities + '\n' +
                'Cases: ' + cases + '\n' +
                'Assets: ' + assets + '\n' +
                'Orders: ' + orders + '\n' +
                'Quotes: ' + quotes + '\n' +
                'Account Territories: ' + accountTerritories + '\n' +
                'Asset Summaries: ' + assetSummaries + '\n' +
                'Client Profile Questions: ' + clientProfileQuestions + '\n\n' +
                'Total related records: ' + totalRelated();
        }
    }

    public class ContactPreview {
        public String action;
        public String reason;
        public Integer opportunities = 0;
        public Integer orderManagementLists = 0;
        public Integer cases = 0;
        public Integer assets = 0;
        public Integer orders = 0;
        public Integer quotes = 0;

        public Integer totalRelated() {
            return opportunities + orderManagementLists + cases + assets + orders + quotes;
        }

        public String summary() {
            if (action == ACTION_INACTIVATED) {
                return 'This Contact will be marked Inactive. It will NOT be deleted.\n' +
                    'Reason: ' + reason + '\n\n' +
                    'Related records stay active and stay linked to the Contact.';
            }
            return 'This Contact will be DELETED.\n' +
                'Reason: ' + reason + '\n\n' +
                'Related records are kept. The Contact will be removed from:\n' +
                'Opportunities (contact fields): ' + opportunities + '\n' +
                'Opportunities (Order Management contact lists): ' + orderManagementLists + '\n' +
                'Cases: ' + cases + '\n' +
                'Assets: ' + assets + '\n' +
                'Orders: ' + orders + '\n' +
                'Quotes: ' + quotes + '\n\n' +
                'Deleted Contacts can be restored from the Recycle Bin for 15 days.';
        }
    }

    public class ContactResult {
        public Id contactId;
        public String name;
        public String netSuiteId;
        public String action;
        public String reason;
        public Integer assetsCleared = 0;
        public Integer opportunitiesUpdated = 0;
        public String error;

        public Boolean isSuccess() {
            return error == null;
        }
    }

    public class ClearedAsset {
        public Id assetId;
        public String assetName;
        public Id accountId;
        public String fieldLabel;
        public Id contactId;
        public String contactName;
    }

    public class RunResult {
        public List<ContactResult> contacts = new List<ContactResult>();
        public List<ClearedAsset> clearedAssets = new List<ClearedAsset>();
    }

    public static Preview previewAccount(Id accountId) {
        validateType(accountId, Account.SObjectType);
        Preview result = new Preview();
        result.contacts = [SELECT COUNT() FROM Contact WHERE AccountId = :accountId];
        result.opportunities = [SELECT COUNT() FROM Opportunity WHERE AccountId = :accountId];
        result.cases = [SELECT COUNT() FROM Case WHERE AccountId = :accountId];
        result.assets = [SELECT COUNT() FROM Asset WHERE AccountId = :accountId];
        result.orders = [SELECT COUNT() FROM Order WHERE AccountId = :accountId];
        result.quotes = [SELECT COUNT() FROM Quote WHERE AccountId = :accountId OR Account__c = :accountId];
        result.accountTerritories = [SELECT COUNT() FROM Account_Territory__c WHERE Account__c = :accountId];
        result.assetSummaries = [SELECT COUNT() FROM Asset_Summary__c WHERE Account__c = :accountId];
        result.clientProfileQuestions = [SELECT COUNT() FROM Client_Profile_Question__c WHERE Account__c = :accountId];
        return result;
    }

    public static ContactPreview previewContact(Id contactId) {
        validateType(contactId, Contact.SObjectType);
        ContactPreview result = new ContactPreview();
        Map<Id, String> holds = findHoldReasons(new Set<Id>{ contactId });
        result.action = holds.containsKey(contactId) ? ACTION_INACTIVATED : ACTION_DELETED;
        result.reason = holds.containsKey(contactId) ? holds.get(contactId) : REASON_NO_ACTIVITY;

        result.opportunities = [SELECT COUNT() FROM Opportunity WHERE ContactId = :contactId OR Primary_Contact__c = :contactId OR Scheduling_Contact__c = :contactId OR Shipping_Contact__c = :contactId OR Contact_for_Payment_AP__c = :contactId OR CLOSA_Contact__c = :contactId OR SolidProfessor_Contact__c = :contactId OR Technical_Resource__c = :contactId];
        result.orderManagementLists = queryOpportunitiesInContactLists(new Set<Id>{ contactId }, availableContactLists()).size();
        result.cases = [SELECT COUNT() FROM Case WHERE ContactId = :contactId];
        result.assets = [SELECT COUNT() FROM Asset WHERE ContactId = :contactId OR Contact__c = :contactId OR Machine_User__c = :contactId];
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

        List<Order> orders = [SELECT Id FROM Order WHERE AccountId = :accountId];
        for (Order record : orders) record.NUKE_Deactivated__c = true;
        updateIfPresent(orders);

        List<Quote> quotes = [SELECT Id FROM Quote WHERE AccountId = :accountId OR Account__c = :accountId];
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

    public static RunResult runContact(Id contactId) {
        validateType(contactId, Contact.SObjectType);
        return processContacts(new Set<Id>{ contactId });
    }

    /**
     * Applies the Contact NUKE rules: a Contact that passes a hold check is inactivated only;
     * any other Contact is removed from related records and deleted (Recycle Bin).
     * Related records are never inactivated or deleted by this method.
     */
    public static RunResult processContacts(Set<Id> contactIds) {
        RunResult result = new RunResult();
        if (contactIds == null || contactIds.isEmpty()) {
            return result;
        }

        Map<Id, ContactResult> resultsById = new Map<Id, ContactResult>();
        for (Contact record : [SELECT Id, Name, celigo_sfnsio__NetSuite_Id__c FROM Contact WHERE Id IN :contactIds]) {
            ContactResult contactResult = new ContactResult();
            contactResult.contactId = record.Id;
            contactResult.name = record.Name;
            contactResult.netSuiteId = record.celigo_sfnsio__NetSuite_Id__c;
            resultsById.put(record.Id, contactResult);
        }

        Map<Id, String> holds = findHoldReasons(resultsById.keySet());
        Set<Id> toDelete = new Set<Id>();
        for (ContactResult contactResult : resultsById.values()) {
            if (holds.containsKey(contactResult.contactId)) {
                contactResult.action = ACTION_INACTIVATED;
                contactResult.reason = holds.get(contactResult.contactId);
            } else {
                contactResult.action = ACTION_DELETED;
                contactResult.reason = REASON_NO_ACTIVITY;
                toDelete.add(contactResult.contactId);
            }
        }

        cleanUpAndDelete(toDelete, resultsById, result);
        inactivateContacts(resultsById);

        result.contacts.addAll(resultsById.values());
        return result;
    }

    public static Map<Id, String> findHoldReasons(Set<Id> contactIds) {
        Map<Id, String> reasons = new Map<Id, String>();
        if (contactIds.isEmpty()) {
            return reasons;
        }

        Date activityCutoff = Date.today().addDays(-365);
        for (Contact record : [SELECT Id FROM Contact WHERE Id IN :contactIds AND LastActivityDate >= :activityCutoff]) {
            reasons.put(record.Id, REASON_RECENT_ACTIVITY);
        }

        Set<Id> remaining = withoutHolds(contactIds, reasons);
        if (!remaining.isEmpty()) {
            for (SurveySubject subject : [SELECT SubjectId FROM SurveySubject WHERE SubjectId IN :remaining AND CreatedDate = LAST_N_DAYS:365]) {
                addHold(reasons, remaining, subject.SubjectId, REASON_RECENT_SURVEY);
            }
        }

        remaining = withoutHolds(contactIds, reasons);
        if (!remaining.isEmpty()) {
            Date orderCutoff = Date.today().addYears(-8);
            List<Order> orders = [
                SELECT EffectiveDate, BillToContactId, ShipToContactId, CustomerAuthorizedById, Order_Contact__c
                FROM Order
                WHERE BillToContactId IN :remaining OR ShipToContactId IN :remaining
                    OR CustomerAuthorizedById IN :remaining OR Order_Contact__c IN :remaining
            ];
            for (Order record : orders) {
                if (record.EffectiveDate >= orderCutoff) {
                    addHold(reasons, remaining, record.BillToContactId, REASON_RECENT_ORDER);
                    addHold(reasons, remaining, record.ShipToContactId, REASON_RECENT_ORDER);
                    addHold(reasons, remaining, record.CustomerAuthorizedById, REASON_RECENT_ORDER);
                    addHold(reasons, remaining, record.Order_Contact__c, REASON_RECENT_ORDER);
                }
            }
            // Older Orders: the standard Order contact fields block a Contact delete, the custom Order Contact clears on delete.
            for (Order record : orders) {
                addHold(reasons, remaining, record.BillToContactId, REASON_ORDER_BLOCKS_DELETE);
                addHold(reasons, remaining, record.ShipToContactId, REASON_ORDER_BLOCKS_DELETE);
                addHold(reasons, remaining, record.CustomerAuthorizedById, REASON_ORDER_BLOCKS_DELETE);
            }
        }

        remaining = withoutHolds(contactIds, reasons);
        if (!remaining.isEmpty()) {
            for (echosign_dev1__SIGN_Recipients__c recipient : [SELECT echosign_dev1__Contact__c FROM echosign_dev1__SIGN_Recipients__c WHERE echosign_dev1__Contact__c IN :remaining]) {
                addHold(reasons, remaining, recipient.echosign_dev1__Contact__c, REASON_ADOBE_SIGN);
            }
            for (echosign_dev1__SIGN_Agreement__c agreement : [
                SELECT echosign_dev1__Recipient__c, echosign_dev1__Recipient2__c, echosign_dev1__Recipient3__c, echosign_dev1__Recipient4__c
                FROM echosign_dev1__SIGN_Agreement__c
                WHERE echosign_dev1__Recipient__c IN :remaining OR echosign_dev1__Recipient2__c IN :remaining
                    OR echosign_dev1__Recipient3__c IN :remaining OR echosign_dev1__Recipient4__c IN :remaining
            ]) {
                addHold(reasons, remaining, agreement.echosign_dev1__Recipient__c, REASON_ADOBE_SIGN);
                addHold(reasons, remaining, agreement.echosign_dev1__Recipient2__c, REASON_ADOBE_SIGN);
                addHold(reasons, remaining, agreement.echosign_dev1__Recipient3__c, REASON_ADOBE_SIGN);
                addHold(reasons, remaining, agreement.echosign_dev1__Recipient4__c, REASON_ADOBE_SIGN);
            }
        }
        return reasons;
    }

    // Runs the pre-delete cleanup and the delete under a savepoint. If any Contact falls back to inactivate
    // (cleanup or delete failed), everything is rolled back and only the remaining Contacts are retried,
    // so cleanup is only kept for Contacts that are actually deleted.
    private static void cleanUpAndDelete(Set<Id> toDelete, Map<Id, ContactResult> resultsById, RunResult result) {
        Set<Id> candidates = new Set<Id>(toDelete);
        for (Integer attempt = 0; attempt < MAX_DELETE_ATTEMPTS && !candidates.isEmpty(); attempt++) {
            Set<Id> attemptSet = new Set<Id>(candidates);
            RunResult attemptResult = new RunResult();
            for (Id contactId : attemptSet) {
                resultsById.get(contactId).assetsCleared = 0;
                resultsById.get(contactId).opportunitiesUpdated = 0;
            }
            Savepoint sp = Database.setSavepoint();
            removeFromOpportunityContactLists(attemptSet, resultsById);
            clearAssets(attemptSet, resultsById, attemptResult);
            deleteContacts(attemptSet, resultsById);
            if (attemptSet.size() == candidates.size()) {
                result.clearedAssets.addAll(attemptResult.clearedAssets);
                return;
            }
            Database.rollback(sp);
            candidates = attemptSet;
        }
        for (Id contactId : candidates) {
            ContactResult contactResult = resultsById.get(contactId);
            contactResult.action = ACTION_INACTIVATED;
            contactResult.reason = REASON_CLEANUP_FAILED + ': retry limit reached';
            contactResult.assetsCleared = 0;
            contactResult.opportunitiesUpdated = 0;
        }
    }

    // Removes Contacts being deleted from the Order Management text lists. A Contact whose entry
    // cannot be matched across the Ids / Names / NetSuite Ids lists is inactivated instead.
    private static void removeFromOpportunityContactLists(Set<Id> toDelete, Map<Id, ContactResult> resultsById) {
        List<List<String>> lists = availableContactLists();
        if (toDelete.isEmpty() || lists.isEmpty()) {
            return;
        }
        List<Opportunity> opportunities = queryOpportunitiesInContactLists(toDelete, lists);
        if (opportunities.isEmpty()) {
            return;
        }
        Map<String, Id> contactsByShortId = new Map<String, Id>();
        for (Id contactId : toDelete) {
            contactsByShortId.put(String.valueOf(contactId).left(15), contactId);
        }

        for (Opportunity opp : opportunities) {
            for (List<String> fields : lists) {
                List<String> ids = parseList((String) opp.get(fields[0]));
                Integer namesSize = parseList((String) opp.get(fields[1])).size();
                Integer netSuiteIdsSize = parseList((String) opp.get(fields[2])).size();
                for (String value : ids) {
                    Id contactId = contactsByShortId.get(value.left(15));
                    if (contactId != null && toDelete.contains(contactId) && (namesSize != ids.size() || netSuiteIdsSize != ids.size())) {
                        fallBackToInactivate(resultsById.get(contactId), REASON_LIST_MISMATCH, toDelete);
                    }
                }
            }
        }
        if (toDelete.isEmpty()) {
            return;
        }

        List<Opportunity> changed = new List<Opportunity>();
        List<Set<Id>> contactsPerChange = new List<Set<Id>>();
        for (Opportunity opp : opportunities) {
            Opportunity updated = new Opportunity(Id = opp.Id);
            Set<Id> removedContacts = new Set<Id>();
            for (List<String> fields : lists) {
                List<String> ids = parseList((String) opp.get(fields[0]));
                List<String> names = parseList((String) opp.get(fields[1]));
                List<String> netSuiteIds = parseList((String) opp.get(fields[2]));
                Boolean listChanged = false;
                for (Integer i = ids.size() - 1; i >= 0; i--) {
                    Id contactId = contactsByShortId.get(ids[i].left(15));
                    if (contactId == null || !toDelete.contains(contactId)) {
                        continue;
                    }
                    ids.remove(i);
                    names.remove(i);
                    netSuiteIds.remove(i);
                    removedContacts.add(contactId);
                    listChanged = true;
                }
                if (listChanged) {
                    updated.put(fields[0], formatList(ids));
                    updated.put(fields[1], formatList(names));
                    updated.put(fields[2], formatList(netSuiteIds));
                }
            }
            if (!removedContacts.isEmpty()) {
                changed.add(updated);
                contactsPerChange.add(removedContacts);
            }
        }
        if (changed.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.update(changed, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            for (Id contactId : contactsPerChange[i]) {
                ContactResult contactResult = resultsById.get(contactId);
                if (saveResults[i].isSuccess()) {
                    contactResult.opportunitiesUpdated++;
                } else {
                    fallBackToInactivate(contactResult, REASON_CLEANUP_FAILED + ' (Opportunity ' + changed[i].Id + '): ' + firstError(saveResults[i].getErrors()), toDelete);
                }
            }
        }
    }

    // Clears the standard Asset Contact before the delete so the Asset can never be removed with the Contact.
    // The custom Contact and Machine User lookups clear automatically on delete; they are listed for the report.
    private static void clearAssets(Set<Id> toDelete, Map<Id, ContactResult> resultsById, RunResult result) {
        if (toDelete.isEmpty()) {
            return;
        }
        List<Asset> assets = [
            SELECT Id, Name, AccountId, ContactId, Contact.Name, Contact__c, Contact__r.Name, Machine_User__c, Machine_User__r.Name
            FROM Asset
            WHERE ContactId IN :toDelete OR Contact__c IN :toDelete OR Machine_User__c IN :toDelete
        ];
        List<Asset> toClear = new List<Asset>();
        for (Asset record : assets) {
            if (record.ContactId != null && toDelete.contains(record.ContactId)) {
                toClear.add(new Asset(Id = record.Id, ContactId = null));
            }
        }
        Set<Id> failedAssets = new Set<Id>();
        if (!toClear.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(toClear, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (!saveResults[i].isSuccess()) {
                    failedAssets.add(toClear[i].Id);
                }
            }
        }
        for (Asset record : assets) {
            if (failedAssets.contains(record.Id)) {
                fallBackToInactivate(resultsById.get(record.ContactId), REASON_CLEANUP_FAILED + ' (Asset ' + record.Id + ')', toDelete);
            }
        }

        for (Asset record : assets) {
            if (failedAssets.contains(record.Id)) {
                continue;
            }
            addClearedAsset(result, resultsById, toDelete, record, record.ContactId, record.Contact?.Name, 'Contact (standard)');
            addClearedAsset(result, resultsById, toDelete, record, record.Contact__c, record.Contact__r?.Name, 'Contact (custom)');
            addClearedAsset(result, resultsById, toDelete, record, record.Machine_User__c, record.Machine_User__r?.Name, 'Machine User');
        }
    }

    private static void addClearedAsset(RunResult result, Map<Id, ContactResult> resultsById, Set<Id> toDelete, Asset record, Id contactId, String contactName, String fieldLabel) {
        if (contactId == null || !toDelete.contains(contactId)) {
            return;
        }
        ClearedAsset cleared = new ClearedAsset();
        cleared.assetId = record.Id;
        cleared.assetName = record.Name;
        cleared.accountId = record.AccountId;
        cleared.fieldLabel = fieldLabel;
        cleared.contactId = contactId;
        cleared.contactName = contactName;
        result.clearedAssets.add(cleared);
        resultsById.get(contactId).assetsCleared++;
    }

    private static void deleteContacts(Set<Id> toDelete, Map<Id, ContactResult> resultsById) {
        if (toDelete.isEmpty()) {
            return;
        }
        List<Id> ids = new List<Id>(toDelete);
        Database.DeleteResult[] deleteResults = Database.delete(ids, false);
        for (Integer i = 0; i < deleteResults.size(); i++) {
            if (!deleteResults[i].isSuccess()) {
                fallBackToInactivate(resultsById.get(ids[i]), REASON_DELETE_FAILED + ': ' + firstError(deleteResults[i].getErrors()), toDelete);
            }
        }
    }

    private static void inactivateContacts(Map<Id, ContactResult> resultsById) {
        List<Contact> toUpdate = new List<Contact>();
        for (ContactResult contactResult : resultsById.values()) {
            if (contactResult.action == ACTION_INACTIVATED) {
                toUpdate.add(new Contact(Id = contactResult.contactId, Inactive__c = true, NUKE__c = false));
            }
        }
        if (toUpdate.isEmpty()) {
            return;
        }
        Database.SaveResult[] saveResults = Database.update(toUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                resultsById.get(toUpdate[i].Id).error = firstError(saveResults[i].getErrors());
            }
        }
    }

    private static List<Opportunity> queryOpportunitiesInContactLists(Set<Id> contactIds, List<List<String>> lists) {
        if (contactIds.isEmpty() || lists.isEmpty()) {
            return new List<Opportunity>();
        }
        List<String> patterns = new List<String>();
        for (Id contactId : contactIds) {
            patterns.add('%' + String.valueOf(contactId).left(15) + '%');
        }
        List<String> fieldNames = new List<String>{ 'Id' };
        List<String> filters = new List<String>();
        for (List<String> fields : lists) {
            fieldNames.addAll(fields);
            filters.add(fields[0] + ' LIKE :patterns');
        }
        String soql = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Opportunity WHERE ' + String.join(filters, ' OR ');
        return (List<Opportunity>) Database.queryWithBinds(soql, new Map<String, Object>{ 'patterns' => patterns }, AccessLevel.SYSTEM_MODE);
    }

    private static List<List<String>> availableContactLists() {
        Map<String, Schema.SObjectField> fieldMap = Opportunity.SObjectType.getDescribe().fields.getMap();
        List<List<String>> available = new List<List<String>>();
        for (List<String> fields : OPPORTUNITY_CONTACT_LISTS) {
            if (fieldMap.containsKey(fields[0]) && fieldMap.containsKey(fields[1]) && fieldMap.containsKey(fields[2])) {
                available.add(fields);
            }
        }
        return available;
    }

    @TestVisible
    private static List<String> parseList(String value) {
        List<String> items = new List<String>();
        if (String.isBlank(value)) {
            return items;
        }
        String listBody = value.trim().removeStart('[').removeEnd(']');
        if (String.isBlank(listBody)) {
            return items;
        }
        for (String item : listBody.split(',', -1)) {
            items.add(item.trim());
        }
        return items;
    }

    @TestVisible
    private static String formatList(List<String> items) {
        return items.isEmpty() ? null : '[' + String.join(items, ',') + ']';
    }

    private static void fallBackToInactivate(ContactResult contactResult, String reason, Set<Id> toDelete) {
        if (contactResult == null || !toDelete.contains(contactResult.contactId)) {
            return;
        }
        toDelete.remove(contactResult.contactId);
        contactResult.action = ACTION_INACTIVATED;
        contactResult.reason = reason;
    }

    private static void addHold(Map<Id, String> reasons, Set<Id> candidates, Id contactId, String reason) {
        if (contactId != null && candidates.contains(contactId) && !reasons.containsKey(contactId)) {
            reasons.put(contactId, reason);
        }
    }

    private static Set<Id> withoutHolds(Set<Id> contactIds, Map<Id, String> reasons) {
        Set<Id> remaining = new Set<Id>(contactIds);
        remaining.removeAll(reasons.keySet());
        return remaining;
    }

    private static String firstError(List<Database.Error> errors) {
        return errors.isEmpty() ? 'Unknown error' : errors[0].getMessage();
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
