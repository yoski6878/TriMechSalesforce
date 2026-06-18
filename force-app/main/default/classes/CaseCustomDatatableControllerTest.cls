@isTest
public class CaseCustomDatatableControllerTest {
    
    @isTest
    static void testMethod1(){
   			Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;

            Contact testContact = new Contact(LastName = 'Test Contact', AccountId = testAccount.Id);
            insert testContact;

            // Create test cases with different statuses
            Case testCase1 = new Case(
                Status = 'New',
                Subject = 'Test Case 1',
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            );
            Case testCase2 = new Case(
                Status = 'Closed',
                Subject = 'Test Case 2',
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            );
            insert new List<Case>{testCase1, testCase2};

            // Test case with status filter
            Test.startTest();
            	List<Case> casesWithFilter = CaseCustomDatatableController.getCaseList('New');
                List<Case> casesWithFilter2 = CaseCustomDatatableController.getCaseList('');
            Test.stopTest();
    }

}