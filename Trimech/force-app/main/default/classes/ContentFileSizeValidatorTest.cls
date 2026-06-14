@IsTest
private class ContentFileSizeValidatorTest {

    // Helper: create a ContentDocument by inserting a ContentVersion with given approx byte size
    private static Id makeVersionWithSize(String title, Integer approxBytes) {
        // Build a string payload close to desired size without exceeding heap
        // Cap to a safe size if called incorrectly
        Integer safeBytes = Math.max(1, Math.min(approxBytes, 2000000)); // ~2 MB cap for safety

        // Build a blob of approximately safeBytes length using simple concatenation (Apex-safe)
        String chunk = 'AAAAAAAAAA'; // 10 chars
        Integer repeats = safeBytes / chunk.length();
        Integer remainder = Math.mod(safeBytes, chunk.length());

        String s = '';
        for (Integer i = 0; i < repeats; i++) {
            s += chunk;
        }
        if (remainder > 0) {
            s += chunk.substring(0, remainder);
        }
        Blob body = Blob.valueOf(s);

        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.txt';
        cv.VersionData = body;
        cv.IsMajorVersion = true;
        insert cv;

        // After insert, query the ContentDocumentId via the created version
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        System.assertNotEquals(null, cv.ContentDocumentId, 'ContentDocumentId should be populated');
        return cv.ContentDocumentId;
    }

    // Helper: does ContentDocument still exist?
    private static Boolean contentDocumentExists(Id docId) {
        return [SELECT count() FROM ContentDocument WHERE Id = :docId] > 0;
    }

    @IsTest
    static void validate_nullRequests_returnsEmpty() {
        Test.startTest();
        List<ContentFileSizeValidator.Result> results = ContentFileSizeValidator.validateAndDeleteOversizeFiles(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null input should return empty results');
    }

    @IsTest
    static void validate_emptyCollection_pass() {
        ContentFileSizeValidator.Request r = new ContentFileSizeValidator.Request();
        r.contentDocumentIds = new List<Id>(); // empty

        Test.startTest();
        List<ContentFileSizeValidator.Result> results =
            ContentFileSizeValidator.validateAndDeleteOversizeFiles(new List<ContentFileSizeValidator.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result must be returned');
        System.assertEquals(true, results[0].isValid, 'Empty list should pass');
        System.assertEquals('PASS', results[0].status, 'Status should be PASS');
        System.assertEquals(0, results[0].violatingDocumentIds.size(), 'No violators expected');
        System.assertEquals('', results[0].errorMessage, 'No error message expected');
    }

    @IsTest
    static void validate_allUnderLimit_defaultPathWithOverrideSmallerLimit() {
        // Create two small files: 100 KB and 200 KB
        Id doc1 = makeVersionWithSize('Small100KB', 100000);
        Id doc2 = makeVersionWithSize('Small200KB', 200000);

        ContentFileSizeValidator.Request r = new ContentFileSizeValidator.Request();
        r.contentDocumentIds = new List<Id>{ doc1, doc2 };
        // Set limit to 300 KB to ensure both are under limit while exercising per-request override path
        r.sizeLimitBytes = 300000;

        Test.startTest();
        List<ContentFileSizeValidator.Result> results =
            ContentFileSizeValidator.validateAndDeleteOversizeFiles(new List<ContentFileSizeValidator.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expect one result');
        ContentFileSizeValidator.Result res = results[0];
        System.assertEquals(true, res.isValid, 'Both files are under 300 KB');
        System.assertEquals('PASS', res.status, 'Status should be PASS');
        System.assertEquals(0, res.violatingDocumentIds.size(), 'No violators expected');
        System.assertEquals('', res.errorMessage, 'No error message expected');

        // Both documents should remain
        System.assertEquals(true, contentDocumentExists(doc1), 'doc1 should not be deleted');
        System.assertEquals(true, contentDocumentExists(doc2), 'doc2 should not be deleted');
    }

    @IsTest
    static void validate_oneOversize_withOverrideTriggersDeletion() {
        // Create small (100 KB) and larger (600 KB)
        Id smallDoc = makeVersionWithSize('Small100KB_2', 100000);
        Id largeDoc = makeVersionWithSize('Large600KB', 600000);

        ContentFileSizeValidator.Request r = new ContentFileSizeValidator.Request();
        r.contentDocumentIds = new List<Id>{ smallDoc, largeDoc };
        // Set limit to 500 KB so only largeDoc violates
        r.sizeLimitBytes = 500000;

        Test.startTest();
        List<ContentFileSizeValidator.Result> results =
            ContentFileSizeValidator.validateAndDeleteOversizeFiles(new List<ContentFileSizeValidator.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expect one result');
        ContentFileSizeValidator.Result res = results[0];
        System.assertEquals(false, res.isValid, 'One file exceeds 500 KB');
        System.assertEquals('FAIL', res.status, 'Status should be FAIL');
        System.assertEquals(1, res.violatingDocumentIds.size(), 'Exactly one violator expected');
        System.assertEquals(largeDoc, res.violatingDocumentIds[0], 'Large doc should be violator');
        System.assertNotEquals('', res.errorMessage, 'Error message should be populated with titles');

        // Ensure deletion happened only for the large document
        System.assertEquals(true, contentDocumentExists(smallDoc), 'Small doc should remain');
        System.assertEquals(false, contentDocumentExists(largeDoc), 'Large doc should be deleted');
    }

    @IsTest
    static void validate_multipleRequests_dedupAndAlignment() {
        Id docSmall = makeVersionWithSize('MultiSmall', 120000);
        Id docLarge = makeVersionWithSize('MultiLarge', 700000);

        ContentFileSizeValidator.Request r1 = new ContentFileSizeValidator.Request();
        r1.contentDocumentIds = new List<Id>{ docSmall, docLarge };
        r1.sizeLimitBytes = 500000; // large violates

        ContentFileSizeValidator.Request r2 = new ContentFileSizeValidator.Request();
        r2.contentDocumentIds = new List<Id>{ docLarge }; // duplicate across requests
        r2.sizeLimitBytes = 500000;

        Test.startTest();
        List<ContentFileSizeValidator.Result> results =
            ContentFileSizeValidator.validateAndDeleteOversizeFiles(new List<ContentFileSizeValidator.Request>{ r1, r2 });
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Alignment: two results back for two requests');

        // r1 result
        System.assertEquals(false, results[0].isValid, 'r1 should be FAIL due to large');
        System.assertEquals('FAIL', results[0].status);
        System.assert(results[0].violatingDocumentIds.contains(docLarge), 'r1 violators should include large');

        // r2 result
        System.assertEquals(false, results[1].isValid, 'r2 should be FAIL due to large');
        System.assertEquals('FAIL', results[1].status);
        System.assertEquals(1, results[1].violatingDocumentIds.size(), 'Only the large doc present in r2');
        System.assertEquals(docLarge, results[1].violatingDocumentIds[0]);

        // Deleted once overall
        System.assertEquals(true, contentDocumentExists(docSmall), 'Small doc should remain');
        System.assertEquals(false, contentDocumentExists(docLarge), 'Large doc should be deleted');
    }

    @IsTest
    static void deleteOversizeFiles_helper_respectsLimitAndDeletes() {
        Id small = makeVersionWithSize('HelperSmall', 100000);
        Id large = makeVersionWithSize('HelperLarge', 650000);

        Test.startTest();
        List<Id> deleted = ContentFileSizeValidator.deleteOversizeFiles(new List<Id>{ small, large }, 500000);
        Test.stopTest();

        System.assertEquals(1, deleted.size(), 'Only the large file should be returned for deletion');
        System.assertEquals(large, deleted[0], 'Large should be deleted');
        System.assertEquals(true, contentDocumentExists(small), 'Small should remain');
        System.assertEquals(false, contentDocumentExists(large), 'Large should be deleted');
    }

    @IsTest
    static void deleteOversizeFiles_emptyInput_returnsEmpty() {
        Test.startTest();
        List<Id> deleted = ContentFileSizeValidator.deleteOversizeFiles(new List<Id>(), 1000);
        Test.stopTest();

        System.assertEquals(0, deleted.size(), 'Empty input should return empty');
    }
}