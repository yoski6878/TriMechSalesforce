global class DuplicateAccountBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    // Each execute() creates one CSV file "part N"
    global String allCsvRows = '';
    global Map<Id, String> uniqueAccounts = new Map<Id, String>();

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Filter to Accounts via semi-join (works on polymorphic RecordId)
        return Database.getQueryLocator(
            'SELECT DuplicateRecordSetId, RecordId ' +
            'FROM DuplicateRecordItem ' +
            'WHERE RecordId IN (SELECT Id FROM Account)'
        );
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<DuplicateRecordItem> items = (List<DuplicateRecordItem>) scope;

        Set<Id> acctIds = new Set<Id>();
        Set<Id> dupSetIds = new Set<Id>();

        for (DuplicateRecordItem dri : items) {
            if (dri.RecordId != null) acctIds.add(dri.RecordId);
            if (dri.DuplicateRecordSetId != null) dupSetIds.add(dri.DuplicateRecordSetId);
        }

        // Pull Accounts for this scope (<= batch size)
        Map<Id, Account> acctsById = new Map<Id, Account>();
        if (!acctIds.isEmpty()) {
            for (Account a : [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :acctIds
            ]) {
                acctsById.put(a.Id, a);
            }
        }

        // Pull DuplicateRecordSet names for this scope
        Map<Id, DuplicateRecordSet> dupSetsById = new Map<Id, DuplicateRecordSet>();
        if (!dupSetIds.isEmpty()) {
            dupSetsById = new Map<Id, DuplicateRecordSet>([
                SELECT Id, Name
                FROM DuplicateRecordSet
                WHERE Id IN :dupSetIds
            ]);
        }

        // Collect unique AccountId and AccountName
        for (DuplicateRecordItem dri : items) {
            if (dri.RecordId != null) {
                Account a = acctsById.get(dri.RecordId);
                String acctId = (a != null ? String.valueOf(a.Id) : String.valueOf(dri.RecordId));
                String acctName = (a != null && a.Name != null ? a.Name : '');
                // Escape quotes for CSV
                acctName = acctName.replace('"','""');
                uniqueAccounts.put(acctId, acctName);
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        try {
            // Build CSV header
            allCsvRows = 'AccountId,AccountName\n';
            for (Id acctId : uniqueAccounts.keySet()) {
                allCsvRows += '"' + acctId + '",';
                allCsvRows += '"' + uniqueAccounts.get(acctId) + '"\n';
            }
            System.debug('DuplicateAccountBatch: CSV string built. Length: ' + allCsvRows.length());
            // Save the single CSV file with all rows
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Duplicate_Accounts_All';
            cv.PathOnClient = cv.Title + '.csv';
            cv.VersionData = Blob.valueOf(allCsvRows);
            insert cv;
            System.debug('DuplicateAccountBatch: ContentVersion inserted. Id: ' + cv.Id);
        } catch (Exception e) {
            System.debug('DuplicateAccountBatch ERROR: ' + e.getMessage());
        }
        System.debug('DuplicateAccountBatch finished. All unique accounts export attempted.');
    }
}