public with sharing class ContentNoteBatchProcessor implements Database.Batchable<String>, Database.Stateful {
    public String staticResourceName;
    public List<String> noteMap = new List<String>();
    public ContentNoteBatchProcessor(String staticResourceName) {
        this.staticResourceName = staticResourceName;
    }
    public Iterable<String> start(Database.BatchableContext bc) {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :staticResourceName LIMIT 1];
        String csv = sr.Body.toString();
        // Use a robust CSV parser for quoted fields and newlines
        List<String> records = new List<String>();
        Boolean inQuotes = false;
        String current = '';
        for (Integer i = 0; i < csv.length(); i++) {
            String c = csv.substring(i, i+1);
            if (c == '"') {
                if (inQuotes && i+1 < csv.length() && csv.substring(i+1, i+2) == '"') {
                    current += '"'; i++;
                } else { inQuotes = !inQuotes; }
            } else if ((c == '\n' || c == '\r') && !inQuotes) {
                records.add(current); current = '';
                if (c == '\r' && i+1 < csv.length() && csv.substring(i+1, i+2) == '\n') i++;
            } else {
                current += c;
            }
        }
        if (current.length() > 0) records.add(current);
        return records;
    }
    public void execute(Database.BatchableContext bc, List<String> scope) {
        List<ContentNote> notes = new List<ContentNote>();
        List<Id> acctIds = new List<Id>();
        for (String line : scope) {
            List<String> cols = new List<String>();
            Boolean inQuotes = false; String field = '';
            for (Integer i = 0; i < line.length(); i++) {
                String c = line.substring(i, i+1);
                if (c == '"') {
                    if (inQuotes && i+1 < line.length() && line.substring(i+1, i+2) == '"') { field += '"'; i++; }
                    else { inQuotes = !inQuotes; }
                } else if (c == ',' && !inQuotes) { cols.add(field); field = ''; }
                else { field += c; }
            }
            cols.add(field);
            if (cols.size() == 2 && String.isNotBlank(cols[0]) && String.isNotBlank(cols[1])) {
                try {
                    notes.add(new ContentNote(Title='Imported Note', Content=Blob.valueOf(cols[1])));
                    acctIds.add((Id)cols[0]);
                } catch (Exception e) { /* skip invalid rows */ }
            }
        }
        if (!notes.isEmpty()) {
            insert notes;
            for (Integer i = 0; i < notes.size(); i++) {
                noteMap.add(notes[i].Id + '^' + acctIds[i]);
            }
        }
    }
    public void finish(Database.BatchableContext bc) {
        // Automate step 2: link notes and update Account.Description
        Map<Id, Id> noteIdToAcctId = new Map<Id, Id>();
        for (String entry : noteMap) {
            List<String> parts = entry.split('^');
            if (parts.size() == 2) noteIdToAcctId.put(parts[0], parts[1]);
        }
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id noteId : noteIdToAcctId.keySet()) {
            Id acctId = noteIdToAcctId.get(noteId);
            if (acctId != null) {
                links.add(new ContentDocumentLink(ContentDocumentId=noteId, LinkedEntityId=acctId, ShareType='V', Visibility='AllUsers'));
            }
        }
        if (!links.isEmpty()) insert links;
        // Update Account.Description
        Set<Id> acctIdsToUpdate = new Set<Id>(noteIdToAcctId.values());
        if (!acctIdsToUpdate.isEmpty()) {
            List<Account> acctsToUpdate = [SELECT Id, Description FROM Account WHERE Id IN :acctIdsToUpdate];
            for (Account acct : acctsToUpdate) {
                acct.Description = 'See Notes';
            }
            update acctsToUpdate;
        }
    }
}