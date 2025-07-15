/**
* @File Name : caseTriggerHandlerTest.cls
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
public class caseTriggerHandlerTest {

    @isTest
    static void testSetCaseValue() {
        // Create test Accounts
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create test Cases
        List<Case> cases = new List<Case>{
            new Case(AccountId = testAccount.Id, Description = 'Short description', Status = 'New'),
            new Case(AccountId = testAccount.Id, Description = null, Status = 'New'),
            new Case(AccountId = testAccount.Id, Description = 'This is a very long description that exceeds 255 characters. ' +
                'It is being used to test the substring logic of the Description_Highlight__c field in the setCaseValue method. ' +
                'The actual length of this description is greater than 255 characters. More padding text to ensure the length.', 
                Status = 'New')
        };
        insert cases;

		cases[0].Description = 'Test Change';

		update cases[0];

		List<Case> newList = new List<Case>(cases);
        List<Case> oldList = new List<Case>(cases);
        Map<Id, Case> newMap = new Map<Id, Case>(cases);
        Map<Id, Case> oldMap = new Map<Id, Case>(cases);

        // Modify descriptions in newList to simulate updates
        for (Case cs : newList) {
            if (cs.Description == null) {
                cs.Description = 'New description for null test';
            } else if (cs.Description.length() > 255) {
                cs.Description = 'Shortened long description';
            }
        }

        Test.startTest();
        caseTriggerHandler.setCaseValue(newList, oldList, newMap, oldMap);
        Test.stopTest();
    }

}