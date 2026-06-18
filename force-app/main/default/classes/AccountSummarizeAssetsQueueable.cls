public with sharing class AccountSummarizeAssetsQueueable implements Queueable {
    // TEMPORARY DISABLE SWITCH: set to false to re-enable processing
    @testVisible private static Boolean disableProcessing = false;

    // Process up to this many accounts in a single execute() to reduce async executions
    private static final Integer MAX_ACCOUNTS_PER_EXEC = 500;
    private static final Integer MAX_RETRIES = 2;

    public List<Id> acctIds;
    private Integer retryCount = 0;

    public AccountSummarizeAssetsQueueable(List<Id> acctIds) {
        this(acctIds, 0);
    }

    public AccountSummarizeAssetsQueueable(List<Id> acctIds, Integer retryCount) {
        this.acctIds = (acctIds == null) ? new List<Id>() : new List<Id>(acctIds);
        this.retryCount = (retryCount == null) ? 0 : retryCount;
    }

    public void execute(QueueableContext context) {
        // Early return if temporarily disabled
        if (disableProcessing) {
            return;
        }

        if (acctIds == null || acctIds.isEmpty()) {
            return;
        }

        // Process up to MAX_ACCOUNTS_PER_EXEC account Ids in this execution
        Integer toProcessCount = Math.min(MAX_ACCOUNTS_PER_EXEC, acctIds.size());
        List<Id> processIds = new List<Id>();
        for (Integer i = 0; i < toProcessCount; i++) {
            processIds.add(acctIds[i]);
        }

        // Prepare to build summaries for all accounts in this chunk
        List<Asset_Summary__c> summariesToUpsert = new List<Asset_Summary__c>();

        // Delete existing summaries for these accounts first (single DML)
        Boolean deleteSuccess = false;
        try {
            Database.delete(
                new List<Asset_Summary__c>(
                    [SELECT Id FROM Asset_Summary__c WHERE Account__c IN :processIds]
                ),
                false
            );
            deleteSuccess = true;
        } catch (DmlException e) {
            // Log the error for monitoring, but continue; upsert below will recreate
            System.debug(LoggingLevel.ERROR, 'Failed to delete existing Asset_Summary__c records: ' + e.getMessage());
        }

        // Query all assets for these accounts in one go (filter Status only for TriMech Assets)
        List<Asset> assets = [
            SELECT Id, AccountId, Quantity, Asset_Type__c, Product2Id, Name, Renewal_Expiration_date__c, RecordType.DeveloperName, Status
            FROM Asset
            WHERE AccountId IN :processIds
            AND Quantity != null
        ];

        // Preload related product2s for the asset set
        Set<Id> productIds = new Set<Id>();
        for (Asset a : assets) {
            if (a.Product2Id != null) {
                productIds.add(a.Product2Id);
            }
        }
        Map<Id, Product2> pMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            for (Product2 p : [SELECT Id, Class__c, Technology__c FROM Product2 WHERE Id IN :productIds]) {
                pMap.put(p.Id, p);
            }
        }

        // Aggregate by account and computed key as before, now with expired status in key
        Map<Id, Map<String, Decimal>> acctKeyToQty = new Map<Id, Map<String, Decimal>>();
        Map<Id, Map<String, String>> acctKeyToType = new Map<Id, Map<String, String>>();
        Map<Id, Map<String, String>> acctKeyToClass = new Map<Id, Map<String, String>>();
        Map<Id, Map<String, String>> acctKeyToTech = new Map<Id, Map<String, String>>();
        Map<Id, Map<String, Boolean>> acctKeyToExpired = new Map<Id, Map<String, Boolean>>();

        for (Asset a : assets) {
            if (a == null || a.AccountId == null) {
                continue;
            }
            // Defensive: skip if Quantity or Asset_Type__c is null
            if (a.Quantity == null || a.Asset_Type__c == null) {
                continue;
            }
            // For TriMech Assets, do not filter by status; include all statuses (including Expired)
            if (!acctKeyToQty.containsKey(a.AccountId)) {
                acctKeyToQty.put(a.AccountId, new Map<String, Decimal>());
                acctKeyToType.put(a.AccountId, new Map<String, String>());
                acctKeyToClass.put(a.AccountId, new Map<String, String>());
                acctKeyToTech.put(a.AccountId, new Map<String, String>());
            }
            Map<String, Decimal> keyToQty = acctKeyToQty.get(a.AccountId);
            Map<String, String> keyToType = acctKeyToType.get(a.AccountId);
            Map<String, String> keyToClass = acctKeyToClass.get(a.AccountId);
            Map<String, String> keyToTech = acctKeyToTech.get(a.AccountId);

            String typeVal = a.Asset_Type__c;
            Product2 p = (a.Product2Id != null && pMap.containsKey(a.Product2Id)) ? pMap.get(a.Product2Id) : null;
            Boolean isSoftware = (typeVal != null && String.valueOf(typeVal) == 'Software');
            String classVal = isSoftware ? (p != null ? p.Class__c : null) : null;
            String techVal = isSoftware ? null : (p != null ? p.Technology__c : null);
            String third = isSoftware ? classVal : techVal;

            String accIdPart = String.valueOf(a.AccountId).substring(0, Math.min(18, String.valueOf(a.AccountId).length()));
            String typePart = String.valueOf(typeVal).substring(0, Math.min(2, String.valueOf(typeVal).length()));
            String thirdPart = String.valueOf(third == null ? '' : third).substring(0, Math.min(11, String.valueOf(third == null ? '' : third).length()));
            // Determine expired status for this asset
            Boolean isExpired = false;
            if (a.Renewal_Expiration_date__c != null && a.Renewal_Expiration_date__c < Date.today()) {
                isExpired = true;
            }
            String expiredPart = isExpired ? 'E' : 'A';
            // Determine TriMech or Competitor using DeveloperName
            String recordTypeVal = (a.RecordType != null && a.RecordType.DeveloperName == 'TriMech_Asset') ? 'T' : (a.RecordType != null && a.RecordType.DeveloperName == 'Competitor_Assets') ? 'C' : '';
            // Remove any old picklist assignment here; will be set per summary below
            String key;
            if (thirdPart != null && thirdPart != '') {
                key = accIdPart + '|' + typePart + '|' + thirdPart + '|' + expiredPart + '|' + recordTypeVal;
            } else {
                key = accIdPart + '|' + typePart + '|' + expiredPart + '|' + recordTypeVal;
            }
            // recordTypePicklist will be determined per summary below

            Decimal q = a.Quantity == null ? 0 : a.Quantity;
            if (!acctKeyToExpired.containsKey(a.AccountId)) {
                acctKeyToExpired.put(a.AccountId, new Map<String, Boolean>());
            }
            Map<String, Boolean> keyToExpired = acctKeyToExpired.get(a.AccountId);
            if (keyToQty.containsKey(key)) {
                q += keyToQty.get(key);
            }
            keyToQty.put(key, q);
            keyToType.put(key, typeVal);
            keyToClass.put(key, classVal);
            keyToTech.put(key, techVal);
            keyToExpired.put(key, isExpired);
        }

        // Build summaries for each account from aggregated maps, with deduplication by Upsert_Key__c
        Map<String, Asset_Summary__c> upsertKeyToSummary = new Map<String, Asset_Summary__c>();
        Map<String, String> upsertKeyToAcct = new Map<String, String>();
        for (Id acctId : acctKeyToQty.keySet()) {
            Map<String, Decimal> keyToQty = acctKeyToQty.get(acctId);
            Map<String, Boolean> keyToExpired = acctKeyToExpired.containsKey(acctId) ? acctKeyToExpired.get(acctId) : new Map<String, Boolean>();
            Integer upsertedCount = 0;
            Integer skippedCount = 0;
            for (String key : keyToQty.keySet()) {
                Decimal total = keyToQty.get(key);
                String typeVal = acctKeyToType.get(acctId).get(key);
                // Only allow valid picklist values
                Set<String> validTypes = new Set<String>{'Computer','Hardware','Printer','Scanner','Software'};
                if (total > 0 && typeVal != null && validTypes.contains(typeVal)) {
                    // Deduplicate: only keep the first summary for each Upsert_Key__c
                    if (!upsertKeyToSummary.containsKey(key)) {
                        String classVal = acctKeyToClass.get(acctId).get(key);
                        String techVal = acctKeyToTech.get(acctId).get(key);
                        String groupVal;
                        if (typeVal == 'Software') {
                            groupVal = (classVal != null && classVal != '') ? typeVal + ' [' + classVal + ']' : typeVal;
                        } else {
                            groupVal = (techVal != null && techVal != '') ? typeVal + ' [' + techVal + ']' : typeVal;
                        }
                        Boolean isExpired = keyToExpired.containsKey(key) ? keyToExpired.get(key) : false;
                        // Determine picklist value for summary based on key
                        String recordTypePicklist = null;
                        if (key.endsWith('|T')) {
                            recordTypePicklist = 'TriMech Asset';
                        } else if (key.endsWith('|C')) {
                            recordTypePicklist = 'Competitor Assets';
                        }
                        Asset_Summary__c summary = new Asset_Summary__c(
                            Account__c = acctId,
                            Asset_Type__c = typeVal,
                            Asset_Class__c = classVal,
                            Asset_Technology__c = techVal,
                            Asset_Count__c = total,
                            Upsert_Key__c = key,
                            Group__c = groupVal,
                            Is_Expired__c = isExpired,
                            Record_Type__c = recordTypePicklist
                        );
                        upsertKeyToSummary.put(key, summary);
                        upsertKeyToAcct.put(key, String.valueOf(acctId));
                        upsertedCount++;
                    } else {
                        System.debug('Duplicate Upsert_Key__c detected, skipping: ' + key + ' (Account: ' + acctId + ')');
                        skippedCount++;
                    }
                } else if (total > 0 && (typeVal == null || !validTypes.contains(typeVal))) {
                    System.debug('Skipping Asset_Summary__c upsert for invalid Asset_Type__c: ' + typeVal + ' (key: ' + key + ')');
                    skippedCount++;
                }
            }
            System.debug('Account ' + acctId + ': Asset_Summary__c upserted: ' + upsertedCount + ', skipped: ' + skippedCount);
        }
        // Add only deduplicated summaries to upsert list
        summariesToUpsert.addAll(upsertKeyToSummary.values());

        if (!summariesToUpsert.isEmpty()) {
            Boolean upsertSuccess = false;
            try {
                upsert summariesToUpsert Upsert_Key__c;
                upsertSuccess = true;
            } catch (DmlException e) {
                // Retry only for UNABLE_TO_LOCK_ROW error
                if (e.getMessage() != null && e.getMessage().contains('UNABLE_TO_LOCK_ROW') && retryCount < MAX_RETRIES && !Test.isRunningTest()) {
                    System.debug(LoggingLevel.ERROR, 'UNABLE_TO_LOCK_ROW detected, retrying. Attempt: ' + (retryCount + 1));
                    // On retry, always re-delete before upsert to avoid duplicates
                    System.enqueueJob(new AccountSummarizeAssetsQueueable(acctIds, retryCount + 1));
                    return;
                } else {
                    System.debug(LoggingLevel.ERROR, 'Upsert failed: ' + e.getMessage());
                }
            }
        }

        // If there are remaining accounts beyond this chunk, re-enqueue once with the remainder
        if (acctIds.size() > toProcessCount) {
            List<Id> remaining = new List<Id>();
            for (Integer i = toProcessCount; i < acctIds.size(); i++) {
                remaining.add(acctIds[i]);
            }
            if (!remaining.isEmpty() && !Test.isRunningTest()) {
                System.enqueueJob(new AccountSummarizeAssetsQueueable(remaining));
            }
        }
    }
}