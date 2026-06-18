/**
* @File Name : CaseGenerationFormControllerTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 30, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 30, 2024 |   | Initial Version
**/


@isTest
public class caseSurveyHeaderControllerTest {

    @isTest
    static void testGetCaseDetails() {
        // Step 1: Set up test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = testAccount.Id);
        insert testContact;

        Case testCase = new Case(
            Subject = 'Test Case',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert testCase;

        // Step 2: Test positive scenario
        Test.startTest();
        caseSurveyHeaderController.caseRecordWrapper result = caseSurveyHeaderController.getCaseDetails(testCase.Id);
        Test.stopTest();

        // Step 3: Validate results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test Contact', result.contactName, 'Contact Name should match');
        System.assertEquals('Test Account', result.accountName, 'Account Name should match');
        System.assertEquals('Test Case', result.subject, 'Subject should match');

    }
}