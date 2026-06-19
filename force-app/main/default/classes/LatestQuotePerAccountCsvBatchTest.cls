@isTest
private class LatestQuotePerAccountCsvBatchTest {

    @testSetup
    static void setupData() {
        // Create 3 accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;

        // Create 2 opportunities per account so we can verify
        // "latest opp per account" logic in OPPORTUNITIES mode.
        List<Opportunity> opps = new List<Opportunity>();
        for (Account a : accounts) {
            opps.add(new Opportunity(
                Name = 'Old Opp - ' + a.Name,
                AccountId = a.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 1000
            ));
            opps.add(new Opportunity(
                Name = 'New Opp - ' + a.Name,
                AccountId = a.Id,
                StageName = 'Qualification',
                CloseDate = Date.today().addDays(60),
                Amount = 2500
            ));
        }
        insert opps;

        // Create multiple quotes per opportunity for QUOTES mode test
        List<Quote> quotes = new List<Quote>();
        for (Opportunity o : opps) {
            quotes.add(new Quote(
                Name = 'Old Quote - ' + o.Name,
                OpportunityId = o.Id,
                Status = 'Draft'
            ));
            quotes.add(new Quote(
                Name = 'New Quote - ' + o.Name,
                OpportunityId = o.Id,
                Status = 'Presented'
            ));
        }
        insert quotes;
    }

    // -------------------------------------------------------------------
    // QUOTES mode tests
    // -------------------------------------------------------------------

    @isTest
    static void testBatchInQuotesModeCreatesCsv() {
        List<Account> accounts = [SELECT Id FROM Account];
        System.assertEquals(3, accounts.size(), 'Expected 3 test accounts');

        List<Quote> allQuotes = [SELECT Id FROM Quote];
        System.assertEquals(12, allQuotes.size(),
            'Expected 12 test quotes (3 accounts x 2 opps x 2 quotes)');

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.QUOTES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Quotes_By_Account_%'
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(1, files.size(), 'Expected exactly 1 quotes CSV file');

        ContentVersion cv = files[0];
        System.assert(cv.PathOnClient.endsWith('.csv'), 'File should be a .csv');

        String csvContent = cv.VersionData.toString();
        System.assert(
            csvContent.startsWith(
                'AccountId,AccountName,OpportunityId,OpportunityName,' +
                'QuoteId,QuoteName,QuoteNumber,QuoteStatus,GrandTotal,QuoteCreatedDate'
            ),
            'CSV should start with quote header'
        );

        // 1 header + 3 data rows (one per account)
        List<String> nonEmptyLines = nonEmptyLines(csvContent);
        System.assertEquals(4, nonEmptyLines.size(),
            'Expected 1 header row + 3 data rows in QUOTES mode');

        for (Account a : accounts) {
            Integer occurrences = csvContent.countMatches(a.Id);
            System.assertEquals(1, occurrences,
                'Each account should appear exactly once. Account: ' + a.Id);
        }
    }

    @isTest
    static void testQuotesModeHandlesNoQuotesGracefully() {
        delete [SELECT Id FROM Quote];

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.QUOTES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Quotes_By_Account_%'
        ];
        System.assertEquals(1, files.size(), 'File should still be created with no quotes');

        String csvContent = files[0].VersionData.toString();
        System.assert(csvContent.startsWith('AccountId,AccountName'),
            'CSV should still contain header even when there are no quotes');

        System.assertEquals(1, nonEmptyLines(csvContent).size(),
            'Expected only the header row when no quotes exist');
    }

    @isTest
    static void testQuotesModeEscapesSpecialCharacters() {
        Account a = new Account(Name = 'Quote "Special" Co');
        insert a;

        Opportunity o = new Opportunity(
            Name = 'Opp for special account',
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert o;

        insert new Quote(
            Name = 'Special Quote',
            OpportunityId = o.Id,
            Status = 'Draft'
        );

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.QUOTES),
            2000
        );
        Test.stopTest();

        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Quotes_By_Account_%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assert(
            cv.VersionData.toString().contains('Quote ""Special"" Co'),
            'Double quotes inside field values should be escaped per RFC 4180'
        );
    }

    // -------------------------------------------------------------------
    // OPPORTUNITIES mode tests
    // -------------------------------------------------------------------

    @isTest
    static void testBatchInOppsModeCreatesCsv() {
        List<Account> accounts = [SELECT Id FROM Account];
        System.assertEquals(3, accounts.size(), 'Expected 3 test accounts');

        List<Opportunity> allOpps = [SELECT Id FROM Opportunity];
        System.assertEquals(6, allOpps.size(),
            'Expected 6 test opportunities (3 accounts x 2 opps)');

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.OPPORTUNITIES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Opps_By_Account_%'
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(1, files.size(), 'Expected exactly 1 opps CSV file');

        ContentVersion cv = files[0];
        System.assert(cv.PathOnClient.endsWith('.csv'), 'File should be a .csv');

        String csvContent = cv.VersionData.toString();
        System.assert(
            csvContent.startsWith(
                'AccountId,AccountName,OpportunityId,OpportunityName,' +
                'StageName,Amount,CloseDate,OpportunityCreatedDate'
            ),
            'CSV should start with opportunity header'
        );

        // 1 header + 3 data rows (one per account)
        List<String> nonEmptyLines = nonEmptyLines(csvContent);
        System.assertEquals(4, nonEmptyLines.size(),
            'Expected 1 header row + 3 data rows in OPPORTUNITIES mode');

        for (Account a : accounts) {
            Integer occurrences = csvContent.countMatches(a.Id);
            System.assertEquals(1, occurrences,
                'Each account should appear exactly once. Account: ' + a.Id);
        }
    }

    @isTest
    static void testOppsModeHandlesNoOppsGracefully() {
        // Delete quotes first (they reference opps)
        delete [SELECT Id FROM Quote];
        delete [SELECT Id FROM Opportunity];

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.OPPORTUNITIES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Opps_By_Account_%'
        ];
        System.assertEquals(1, files.size(), 'File should still be created with no opps');

        String csvContent = files[0].VersionData.toString();
        System.assert(csvContent.startsWith('AccountId,AccountName'),
            'CSV should still contain header even when there are no opps');

        System.assertEquals(1, nonEmptyLines(csvContent).size(),
            'Expected only the header row when no opps exist');
    }

    @isTest
    static void testOppsModeEscapesSpecialCharacters() {
        Account a = new Account(Name = 'Opp "Special" Co');
        insert a;

        insert new Opportunity(
            Name = 'Special Opp',
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.OPPORTUNITIES),
            2000
        );
        Test.stopTest();

        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Opps_By_Account_%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assert(
            cv.VersionData.toString().contains('Opp ""Special"" Co'),
            'Double quotes inside field values should be escaped per RFC 4180'
        );
    }

    // -------------------------------------------------------------------
    // Multi-file splitting test (uses @TestVisible threshold override)
    // -------------------------------------------------------------------

    @isTest
    static void testBatchSplitsIntoMultipleFilesWhenThresholdExceeded() {
        // Force a tiny threshold so our 3 test accounts split across files.
        // With ROWS_PER_FILE = 2 and 3 unique accounts:
        //   - Part 1: 2 rows (flush triggered)
        //   - Part 2: 1 remaining row (flushed in finish())
        LatestQuotePerAccountCsvBatch.ROWS_PER_FILE = 2;

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.OPPORTUNITIES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Opps_By_Account_%'
            ORDER BY Title ASC
        ];

        System.assertEquals(2, files.size(),
            'Expected the batch to produce 2 part files when threshold is exceeded');

        // Both files should have the header and include _part in their name
        Boolean foundPart1 = false;
        Boolean foundPart2 = false;
        Integer totalDataRows = 0;

        for (ContentVersion cv : files) {
            String content = cv.VersionData.toString();
            System.assert(
                content.startsWith('AccountId,AccountName'),
                'Each part file should contain the CSV header. Got: ' + cv.Title
            );
            System.assert(
                cv.Title.contains('_part'),
                'Each file name should include a _part suffix. Got: ' + cv.Title
            );

            if (cv.Title.endsWith('_part1')) foundPart1 = true;
            if (cv.Title.endsWith('_part2')) foundPart2 = true;

            // Count data rows (lines minus the header)
            totalDataRows += nonEmptyLines(content).size() - 1;
        }

        System.assert(foundPart1, 'Expected a _part1 file');
        System.assert(foundPart2, 'Expected a _part2 file');
        System.assertEquals(3, totalDataRows,
            'Total data rows across all files should equal the number of unique accounts');
    }

    @isTest
    static void testBatchDoesNotProduceEmptyTrailingFile() {
        // With threshold = 3 and exactly 3 accounts, all rows fit in one part.
        // Verifies finish() does NOT create an extra empty part2 file.
        LatestQuotePerAccountCsvBatch.ROWS_PER_FILE = 3;

        Test.startTest();
        Database.executeBatch(
            new LatestQuotePerAccountCsvBatch(LatestQuotePerAccountCsvBatch.Mode.OPPORTUNITIES),
            2000
        );
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title LIKE 'Latest_Opps_By_Account_%'
        ];

        System.assertEquals(1, files.size(),
            'Expected exactly 1 file when row count equals the threshold exactly — ' +
            'no empty trailing part file should be created');
    }

    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------

    private static List<String> nonEmptyLines(String csvContent) {
        List<String> result = new List<String>();
        for (String line : csvContent.split('\n')) {
            if (String.isNotBlank(line)) result.add(line);
        }
        return result;
    }
}