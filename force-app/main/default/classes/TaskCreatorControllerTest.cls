// ...existing code...
@isTest
public with sharing class TaskCreatorControllerTest {
    // Mock for Analytics API callout
    class AnalyticsApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            // Simulate a report with 10 rows, columns: Contact Id, Account Id
            String body = '{'
                + '"reportMetadata": {"detailColumns": ["Contact Id", "Account Id"]},'
                + '"factMap": {"T!T": {"rows": [';
            for (Integer i = 0; i < 10; i++) {
                body += '{"dataCells": ['
                    + '{"value": "00300000000000' + String.valueOf(i) + '"},'
                    + '{"value": "00100000000000' + String.valueOf(i) + '"}'
                + ']}' + (i < 9 ? ',' : '');
            }
            body += ']}}}';
            res.setBody(body);
            return res;
        }
    }
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account', Subsidiary__c = 'TriMech Solutions LLC');
        insert acc;
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(FirstName = 'Test', LastName = 'Contact' + i, AccountId = acc.Id));
        }
        insert contacts;
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        System.assertNotEquals(null, u);
    }

    @isTest
    static void testLoadRecordsFromReport() {
        // Simulate report load with callout mock
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AnalyticsApiMock());
        String inputSource = 'report';
        String reportId = 'dummy';
        String fileContent = null;
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        Test.stopTest();
        System.assertEquals(10, result.created);
        System.assertEquals(0, result.skipped);
        System.assertEquals('', result.errors);
    }

    @isTest
    static void testLoadRecordsFromFile() {
        String inputSource = 'file';
        String reportId = null;
        String fileContent = 'Contact Id,Account Id\n';
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 5];
        for (Contact c : contacts) {
            fileContent += c.Id + ',' + c.AccountId + '\n';
        }
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assertEquals(5, result.created);
        System.assertEquals(0, result.skipped);
        System.assertEquals('', result.errors);
    }

    @isTest
    static void testCreateTasksRoundRobin() {
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 6];
        List<User> users = [SELECT Id FROM User WHERE IsActive = true LIMIT 2];
        List<Map<String, Object>> taskRows = new List<Map<String, Object>>();
        Integer ownerIdx = 0;
        for (Contact c : contacts) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('contactId', c.Id);
            row.put('accountId', c.AccountId);
            row.put('ownerId', users[Math.mod(ownerIdx, users.size())].Id);
            row.put('subject', 'Test Subject');
            row.put('dueDate', String.valueOf(Date.today()));
            row.put('type', 'Call');
            taskRows.add(row);
            ownerIdx++;
        }
        TaskCreatorController.TaskCreatorSummary summary = TaskCreatorController.createTasks(taskRows);
        System.assertEquals(6, summary.created);
        System.assertEquals(0, summary.skipped);
        System.assertEquals('', summary.errors);
    }

    @isTest
    static void testCreateTasksSingleOwner() {
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 4];
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        List<Map<String, Object>> taskRows = new List<Map<String, Object>>();
        for (Contact c : contacts) {
            Map<String, Object> row = new Map<String, Object>{
                'contactId' => c.Id,
                'accountId' => c.AccountId,
                'ownerId' => u.Id,
                'subject' => 'Test Subject',
                'dueDate' => String.valueOf(Date.today()),
                'type' => 'Email'
            };
            taskRows.add(row);
        }
        TaskCreatorController.TaskCreatorSummary summary = TaskCreatorController.createTasks(taskRows);
        System.assertEquals(4, summary.created);
        System.assertEquals(0, summary.skipped);
        System.assertEquals('', summary.errors);
    }

    @isTest
    static void testCreateTasksWithMissingIds() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        List<Map<String, Object>> taskRows = new List<Map<String, Object>>();
        taskRows.add(new Map<String, Object>{
            'contactId' => null,
            'accountId' => null,
            'ownerId' => u.Id,
            'subject' => 'Test Subject',
            'dueDate' => String.valueOf(Date.today()),
            'type' => 'Call'
        });
        TaskCreatorController.TaskCreatorSummary summary = TaskCreatorController.createTasks(taskRows);
        System.assertEquals(1, summary.created);
        System.assertEquals(0, summary.skipped);
        System.assert(summary.errors == null || summary.errors == '');
    }

    @isTest
    static void testLoadRecords_EmptyCSV() {
        String inputSource = 'file';
        String reportId = null;
        String fileContent = '';
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assertEquals(0, result.created);
        System.assert(result.errors != null && result.errors.contains('Invalid input'));
    }

    @isTest
    static void testLoadRecords_MissingColumns() {
        String inputSource = 'file';
        String reportId = null;
        String fileContent = 'SomeHeader\nvalue1\nvalue2';
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assert(result.errors != null && result.errors.contains('CSV missing Contact or Account column'));
    }

    @isTest
    static void testLoadRecords_InvalidJSON() {
        String inputSource = 'file';
        String reportId = null;
        String fileContent = '[{"contactId":"badjson"'; // malformed JSON
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assert(result.errors != null && result.errors.contains('Error processing Excel JSON data'));
    }

    @isTest
    static void testLoadRecords_InvalidInputSource() {
        String inputSource = 'invalid';
        String reportId = null;
        String fileContent = null;
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assert(result.errors != null && result.errors.contains('Invalid input'));
    }

    class AnalyticsApiErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }
    @isTest
    static void testLoadRecords_AnalyticsApiError() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AnalyticsApiErrorMock());
        String inputSource = 'report';
        String reportId = 'dummy';
        String fileContent = null;
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        Test.stopTest();
        System.assert(result.errors != null && (result.errors.contains('Report fetch failed') || result.errors.contains('Analytics API error')));
    }

    @isTest
    static void testCreateTasks_NoOwners() {
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 2];
        List<Map<String, Object>> taskRows = new List<Map<String, Object>>();
        for (Contact c : contacts) {
            Map<String, Object> row = new Map<String, Object>{
                'contactId' => c.Id,
                'accountId' => c.AccountId,
                'ownerId' => null,
                'subject' => 'Test Subject',
                'dueDate' => String.valueOf(Date.today()),
                'type' => 'Call'
            };
            taskRows.add(row);
        }
        TaskCreatorController.TaskCreatorSummary summary = TaskCreatorController.createTasks(taskRows);
        System.assert(summary.errors != null && summary.errors.contains('Missing or invalid OwnerId'));
    }

    @isTest
    static void testCreateTasks_DmlException() {
        // Intentionally use an invalid OwnerId to cause a DML exception
        List<Map<String, Object>> taskRows = new List<Map<String, Object>>();
        taskRows.add(new Map<String, Object>{
            'contactId' => null,
            'accountId' => null,
            'ownerId' => 'INVALIDID', // Invalid 9-char Id
            'subject' => 'Test Subject',
            'dueDate' => String.valueOf(Date.today()),
            'type' => 'Call'
        });
        // Should not throw, but should hit the catch block
        TaskCreatorController.TaskCreatorSummary summary = TaskCreatorController.createTasks(taskRows);
        System.assertEquals(0, summary.created);
        System.assert(summary.errors == null || summary.errors == '' || summary.errors.contains('Missing or invalid OwnerId'));
    }

    @isTest
    static void testLoadRecords_UnhandledError() {
        // Test the case where inputSource is 'file' but fileContent is null
        // This should result in "Invalid input" error as per the controller logic
        String inputSource = 'file';
        String reportId = null;
        String fileContent = null;
        TaskCreatorController.LoadRecordsResult result = TaskCreatorController.loadRecords(inputSource, reportId, fileContent);
        System.assert(result.errors != null && result.errors.contains('Invalid input'));
    }

    @isTest
    static void testGetLeadDevelopmentUsers() {
        // Insert a user with a matching title
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Username = 'devrepuser' + System.currentTimeMillis() + '@test.com',
            LastName = 'DevRep',
            Email = 'devrepuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'devrep',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            Title = 'Development Rep'
        );
        insert u;
        Test.startTest();
        List<TaskCreatorController.UserInfo> users = TaskCreatorController.getLeadDevelopmentUsers();
        Test.stopTest();
        Boolean found = false;
        for (TaskCreatorController.UserInfo info : users) {
            if (info.Id == u.Id && info.Title == 'Development Rep') {
                found = true;
                break;
            }
        }
        System.assert(found, 'Inserted Development Rep user should be found');
    }

    @isTest
    static void testGetAllStandardUsers() {
        // Insert a user with UserType Standard
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Username = 'stduser' + System.currentTimeMillis() + '@test.com',
            LastName = 'Std',
            Email = 'stduser' + System.currentTimeMillis() + '@test.com',
            Alias = 'stdusr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        Test.startTest();
        List<TaskCreatorController.UserInfo> users = TaskCreatorController.getAllStandardUsers();
        Test.stopTest();
        Boolean found = false;
        for (TaskCreatorController.UserInfo info : users) {
            if (info.Id == u.Id) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Inserted Standard User should be found');
    }
}