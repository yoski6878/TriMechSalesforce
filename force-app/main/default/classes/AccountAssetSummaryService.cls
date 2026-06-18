public class AccountAssetSummaryService {
    public static void recalculate(Set<Id> acctIds) {
            // To track all upsert keys for orphan cleanup
            Map<Id, Set<String>> acctToUpsertKeys = new Map<Id, Set<String>>();
        if (acctIds == null || acctIds.isEmpty()) {
            return;
        }

        // Internal chunking for large account sets
        Integer chunkSize = 200;
        List<Id> acctIdList = new List<Id>(acctIds);
        for (Integer offset = 0; offset < acctIdList.size(); offset += chunkSize) {
            Set<Id> chunkAcctIds = new Set<Id>();
            for (Integer i = offset; i < Math.min(offset + chunkSize, acctIdList.size()); i++) {
                chunkAcctIds.add(acctIdList[i]);
            }

            // Query all assets for these accounts in one go (filter Status only for TriMech Assets)
            List<Asset> assets = [
                SELECT Id, AccountId, Quantity, Asset_Type__c, Product2Id, Name, Renewal_Expiration_date__c, RecordType.DeveloperName, Status
                FROM Asset
                WHERE AccountId IN :chunkAcctIds
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

            // Move validTypes set outside the loop
            Set<String> validTypes = new Set<String>{'Computer','Hardware','Printer','Scanner','Software'};

            // Track upsert keys for this chunk for orphan cleanup
            Map<Id, Set<String>> chunkAcctToUpsertKeys = new Map<Id, Set<String>>();

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
                    // Also treat Status = 'Expired' as expired
                    if (a.Status == 'Expired') {
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

                // Track upsert keys for orphan cleanup
                if (!chunkAcctToUpsertKeys.containsKey(a.AccountId)) {
                    chunkAcctToUpsertKeys.put(a.AccountId, new Set<String>());
                }
                chunkAcctToUpsertKeys.get(a.AccountId).add(key);
            }

            // Build summaries for each account from aggregated maps, with deduplication by Upsert_Key__c
            Map<String, Asset_Summary__c> upsertKeyToSummary = new Map<String, Asset_Summary__c>();
            for (Id acctId : acctKeyToQty.keySet()) {
                Map<String, Decimal> keyToQty = acctKeyToQty.get(acctId);
                Map<String, Boolean> keyToExpired = acctKeyToExpired.containsKey(acctId) ? acctKeyToExpired.get(acctId) : new Map<String, Boolean>();
                for (String key : keyToQty.keySet()) {
                    Decimal total = keyToQty.get(key);
                    String typeVal = acctKeyToType.get(acctId).get(key);
                    if (total > 0 && typeVal != null && validTypes.contains(typeVal)) {
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
                        }
                    }
                }
            }
            // Add only deduplicated summaries to upsert list
            List<Asset_Summary__c> summariesToUpsert = new List<Asset_Summary__c>();
            summariesToUpsert.addAll(upsertKeyToSummary.values());

            if (!summariesToUpsert.isEmpty()) {
                try {
                    upsert summariesToUpsert Upsert_Key__c;
                } catch (DmlException e) {
                    // Upsert failed
                }
            }

            // Bulkified orphan cleanup: query all summaries for chunkAcctIds at once
            Map<Id, Set<String>> newKeysByAcct = chunkAcctToUpsertKeys;
            Map<Id, List<Asset_Summary__c>> acctToSummaries = new Map<Id, List<Asset_Summary__c>>();
            List<Asset_Summary__c> allSummaries = [SELECT Id, Upsert_Key__c, Account__c FROM Asset_Summary__c WHERE Account__c IN :chunkAcctIds];
            for (Asset_Summary__c summary : allSummaries) {
                if (!acctToSummaries.containsKey(summary.Account__c)) {
                    acctToSummaries.put(summary.Account__c, new List<Asset_Summary__c>());
                }
                acctToSummaries.get(summary.Account__c).add(summary);
            }
            List<Asset_Summary__c> toDelete = new List<Asset_Summary__c>();
            for (Id acctId : chunkAcctIds) {
                Set<String> newKeys = newKeysByAcct.containsKey(acctId) ? newKeysByAcct.get(acctId) : new Set<String>();
                List<Asset_Summary__c> summaries = acctToSummaries.containsKey(acctId) ? acctToSummaries.get(acctId) : new List<Asset_Summary__c>();
                for (Asset_Summary__c oldSummary : summaries) {
                    if (!newKeys.contains(oldSummary.Upsert_Key__c)) {
                        toDelete.add(oldSummary);
                    }
                }
            }
            if (!toDelete.isEmpty()) {
                try {
                    delete toDelete;
                } catch (DmlException e) {
                    // Delete failed
                }
            }
        }
    }
}