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
            new Case(AccountId = testAccount.Id, Description = null, Status = 'In Progress'),
            new Case(AccountId = testAccount.Id, Description = 'This is a very long description that exceeds 255 characters. ' +
                'It is being used to test the substring logic of the Description_Highlight__c field in the setCaseValue method. ' +
                'The actual length of this description is greater than 255 characters. More padding text to ensure the length.', 
                Status = 'New')
        };
        insert cases;

		cases[0].Description = 'Test Change';

		update cases[0];
        
        cases[1].Status = 'Waiting for client';
        update cases[1];

		List<Case> newList = new List<Case>(cases);
        List<Case> oldList = new List<Case>(cases);
        Map<Id, Case> newMap = new Map<Id, Case>(cases);
        Map<Id, Case> oldMap = new Map<Id, Case>(cases);

        // Modify descriptions in newList to simulate updates
        for (Case cs : newList) {
            cs.Status = 'In Progress';
            if (cs.Description == null) {
                cs.Description = 'New description for null test';
            } else if (cs.Description.length() > 255) {
                cs.Description = 'Shortened long description';
            }
        }

        Test.startTest();
            caseTriggerHandler.setCaseValue(newList, oldList, newMap, oldMap);
            caseTriggerHandler.updateInProgressTime(newList,oldMap);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateAssetPMDate_NoAsserts() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Assets
        Asset asset1 = new Asset(
            Name = 'Asset 1',
            AccountId = acc.Id,
            Status = 'Installed'
        );
        insert asset1;

        Asset asset2 = new Asset(
            Name = 'Asset 2',
            AccountId = acc.Id,
            Status = 'Installed'
        );
        insert asset2;

        // 1️⃣ Insert PM Case with Asset
        Case pmCase = new Case(
            AccountId = acc.Id,
            AssetId = asset1.Id,
            Status = 'New',
            Type = 'Printer Preventative Maintenance'
        );

        Test.startTest();
        insert pmCase;
        Test.stopTest();

        // 2️⃣ Insert non-PM Case, then update Type → PM
        Case typeChangeCase = new Case(
            AccountId = acc.Id,
            AssetId = asset1.Id,
            Status = 'New',
            Type = 'Other'
        );
        insert typeChangeCase;

        typeChangeCase.Type = 'Printer Preventative Maintenance';
        update typeChangeCase;

        pmCase.AssetId = asset2.Id;
        update pmCase;

    }
}