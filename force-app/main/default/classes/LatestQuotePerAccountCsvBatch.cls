public class LatestQuotePerAccountCsvBatch
    implements Database.Batchable<sObject>, Database.Stateful {

    public enum Mode { QUOTES, OPPORTUNITIES }

    @TestVisible
    private static Integer ROWS_PER_FILE = 25000;

    // UTF-8 BOM for Excel compatibility
    private static final String UTF8_BOM = '\uFEFF';

    private Mode runMode;
    private String header;
    private List<String> bufferRows;   // ← list instead of String for perf
    private Integer bufferRowCount = 0;
    private Integer filePartNumber = 1;
    private String runTimestamp;

    // Track only the current account, not all of them
    private Id lastSeenAccountId;

    private Integer rowsWritten = 0;
    private List<Id> contentVersionIds = new List<Id>();

    public LatestQuotePerAccountCsvBatch(Mode m) {
        this.runMode = m;
        this.runTimestamp = System.now().format('yyyyMMdd_HHmmss');
        this.header = (m == Mode.QUOTES)
            ? 'AccountId,AccountName,OpportunityId,OpportunityName,QuoteId,QuoteName,QuoteNumber,QuoteStatus,GrandTotal,QuoteCreatedDate'
            : 'AccountId,AccountName,OpportunityId,OpportunityName,StageName,Amount,CloseDate,OpportunityCreatedDate';
        this.bufferRows = new List<String>();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (runMode == Mode.QUOTES) {
            return Database.getQueryLocator(
                'SELECT Id, Name, QuoteNumber, Status, GrandTotal, CreatedDate, ' +
                '       OpportunityId, Opportunity.Name, ' +
                '       Opportunity.AccountId, Opportunity.Account.Name ' +
                'FROM Quote ' +
                'WHERE Opportunity.AccountId != null ' +
                'ORDER BY Opportunity.AccountId, CreatedDate DESC, Id DESC'
            );
        } else {
            return Database.getQueryLocator(
                'SELECT Id, Name, StageName, Amount, CloseDate, CreatedDate, ' +
                '       AccountId, Account.Name ' +
                'FROM Opportunity ' +
                'WHERE AccountId != null ' +
                'ORDER BY AccountId, CreatedDate DESC, Id DESC'
            );
        }
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (runMode == Mode.QUOTES) {
            for (sObject s : scope) {
                Quote q = (Quote) s;
                Id acctId = q.Opportunity.AccountId;

                // Sorted by AccountId, so skip everything but the first
                // row per account (which is the newest).
                if (acctId == lastSeenAccountId) continue;
                lastSeenAccountId = acctId;
                rowsWritten++;
                bufferRowCount++;

                bufferRows.add(
                    esc(String.valueOf(acctId)) + ',' +
                    esc(q.Opportunity.Account.Name) + ',' +
                    esc(String.valueOf(q.OpportunityId)) + ',' +
                    esc(q.Opportunity.Name) + ',' +
                    esc(String.valueOf(q.Id)) + ',' +
                    esc(q.Name) + ',' +
                    esc(q.QuoteNumber) + ',' +
                    esc(q.Status) + ',' +
                    esc(q.GrandTotal == null ? '' : String.valueOf(q.GrandTotal)) + ',' +
                    esc(String.valueOf(q.CreatedDate))
                );

                if (bufferRowCount >= ROWS_PER_FILE) {
                    writeCurrentBufferToFile();
                    resetBuffer();
                }
            }
        } else {
            for (sObject s : scope) {
                Opportunity o = (Opportunity) s;
                Id acctId = o.AccountId;

                if (acctId == lastSeenAccountId) continue;
                lastSeenAccountId = acctId;
                rowsWritten++;
                bufferRowCount++;

                bufferRows.add(
                    esc(String.valueOf(acctId)) + ',' +
                    esc(o.Account.Name) + ',' +
                    esc(String.valueOf(o.Id)) + ',' +
                    esc(o.Name) + ',' +
                    esc(o.StageName) + ',' +
                    esc(o.Amount == null ? '' : String.valueOf(o.Amount)) + ',' +
                    esc(o.CloseDate == null ? '' : String.valueOf(o.CloseDate)) + ',' +
                    esc(String.valueOf(o.CreatedDate))
                );

                if (bufferRowCount >= ROWS_PER_FILE) {
                    writeCurrentBufferToFile();
                    resetBuffer();
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (bufferRowCount > 0 || contentVersionIds.isEmpty()) {
            writeCurrentBufferToFile();
        }

        System.debug('CSV export complete.');
        System.debug('Mode: ' + runMode);
        System.debug('Total rows written (excluding headers): ' + rowsWritten);
        System.debug('Files created: ' + contentVersionIds.size());
        for (Id cvId : contentVersionIds) {
            System.debug('ContentVersion Id: ' + cvId);
        }
    }

    private void writeCurrentBufferToFile() {
        String prefix = (runMode == Mode.QUOTES)
            ? 'Latest_Quotes_By_Account_'
            : 'Latest_Opps_By_Account_';

        // Build the file content: BOM + header + rows
        String fileContent = UTF8_BOM + header + '\n';
        if (!bufferRows.isEmpty()) {
            fileContent += String.join(bufferRows, '\n') + '\n';
        }

        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = prefix + runTimestamp + '_part' + filePartNumber;
            cv.PathOnClient = cv.Title + '.csv';
            cv.VersionData = Blob.valueOf(fileContent);
            insert cv;

            contentVersionIds.add(cv.Id);
            filePartNumber++;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Failed to insert CSV part ' + filePartNumber + ': ' + e.getMessage());
            throw e;
        }
    }

    private void resetBuffer() {
        bufferRows = new List<String>();
        bufferRowCount = 0;
    }

    private static String esc(String value) {
        if (value == null) return '""';
        return '"' + value.replace('"', '""') + '"';
    }
}