@isTest
public class ReusableLookupControllerTest {
    @testSetup
    static void setup() {
        // Create test Accounts
        Account acc1 = new Account(Name = 'Test Account 1', Phone = '1234567890');
        Account acc2 = new Account(Name = 'Test Account 2', Phone = '0987654321');
        insert acc1;
        insert acc2;

        // Create a parent Account
        Account parentAcc = new Account(Name = 'Parent Account');
        insert parentAcc;

        // Create child Accounts with the parent Account ID
        Account childAcc1 = new Account(Name = 'Child Account 1', Phone = '1111111111', ParentId = parentAcc.Id);
        Account childAcc2 = new Account(Name = 'Child Account 2', Phone = '2222222222', ParentId = parentAcc.Id);
        insert childAcc1;
        insert childAcc2;
    }

    @isTest
    static void testFetchRecordsWithValidSearchString() {
        // Create a SearchWrapper instance
        ReusableLookupController.SearchWrapper searchWrapper = new ReusableLookupController.SearchWrapper();
        searchWrapper.objectApiName = 'Account';
        searchWrapper.fieldApiName = 'Name';
        searchWrapper.otherFieldApiName = 'Phone';
        searchWrapper.searchString = 'Test Account';

        Test.startTest();
        List<ReusableLookupController.ResultWrapper> results = ReusableLookupController.fetchRecords(searchWrapper);
        Test.stopTest();

    }

    @isTest
    static void testFetchRecordsWithSelectedRecordId() {
        // Get a test Account
        Account acc1 = [SELECT Id, Name, Phone FROM Account WHERE Name = 'Test Account 1' LIMIT 1];

        // Create a SearchWrapper instance
        ReusableLookupController.SearchWrapper searchWrapper = new ReusableLookupController.SearchWrapper();
        searchWrapper.objectApiName = 'Account';
        searchWrapper.fieldApiName = 'Name';
        searchWrapper.otherFieldApiName = 'Phone';
        searchWrapper.selectedRecordId = acc1.Id;

    }

    @isTest
    static void testFetchRecordsWithParentFieldApiNameAndParentRecordId() {
        // Get the parent account
        Account parentAcc = [SELECT Id, Name FROM Account WHERE Name = 'Parent Account' LIMIT 1];

        // Create a SearchWrapper instance
        ReusableLookupController.SearchWrapper searchWrapper = new ReusableLookupController.SearchWrapper();
        searchWrapper.objectApiName = 'Account';
        searchWrapper.fieldApiName = 'Name';
        searchWrapper.otherFieldApiName = 'Phone';
        searchWrapper.parentFieldApiName = 'ParentId';
        searchWrapper.parentRecordId = parentAcc.Id;

    }

    @isTest
    static void testFetchRecordsWithNullSearchWrapper() {
        Test.startTest();
        List<ReusableLookupController.ResultWrapper> results = ReusableLookupController.fetchRecords(null);
        Test.stopTest();
    }

    @isTest
    static void testFetchRecordsWithException() {
        // Create a SearchWrapper instance with invalid objectApiName
        ReusableLookupController.SearchWrapper searchWrapper = new ReusableLookupController.SearchWrapper();
        searchWrapper.objectApiName = 'InvalidObject';
        searchWrapper.fieldApiName = 'Name';
        searchWrapper.otherFieldApiName = 'Phone';
        searchWrapper.searchString = 'Invalid Search';

        try {
            Test.startTest();
            List<ReusableLookupController.ResultWrapper> results = ReusableLookupController.fetchRecords(searchWrapper);
            Test.stopTest();
        } catch (Exception e) {
            System.debug('testFetchRecordsWithException exception: ' + e.getMessage());
        }
    }
}