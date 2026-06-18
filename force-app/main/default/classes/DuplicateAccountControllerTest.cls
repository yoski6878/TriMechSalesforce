@isTest
public class DuplicateAccountControllerTest {
    @testSetup
    static void setup() {
        // Create original account
        Account originalAccount = new Account(
            Name = 'Original Account',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingCountry = 'USA',
            BillingPostalCode = '94105',
            Phone = '415-555-1234',
            Website = 'http://www.original.com'
        );
        insert originalAccount;
        
        // Create duplicate account
        Account duplicateAccount = new Account(
            Name = 'Duplicate Account',
            BillingStreet = '456 Elm St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingCountry = 'USA',
            BillingPostalCode = '94105',
            Phone = '415-555-5678',
            Website = 'http://www.duplicate.com'
        );
        insert duplicateAccount;
    }

    @isTest
    static void testSendEmail() {
        // Get accounts
        Account originalAccount = [SELECT Id, Name FROM Account WHERE Name = 'Original Account' LIMIT 1];
        Account duplicateAccount = [SELECT Id, Name FROM Account WHERE Name = 'Duplicate Account' LIMIT 1];
        
        // Create JSON strings
        String originalJson = JSON.serialize(new List<Account> { originalAccount });
        String duplicateJson = JSON.serialize(new List<Account> { duplicateAccount });
        
        // Call sendemail method
        Test.startTest();
        DuplicateAccountController.sendemail('Test notes', originalAccount.Id, originalJson, duplicateJson);
        Test.stopTest();
        
        // Verify accounts were updated
        Account updatedOriginal = [SELECT Id, isSubmitted__c, Notes__c FROM Account WHERE Id = :originalAccount.Id];
        Account updatedDuplicate = [SELECT Id, isSubmitted__c, Notes__c FROM Account WHERE Id = :duplicateAccount.Id];
        
       
    }
    
    @isTest
    static void testDuplicateRecords() {
        // Get original account
        Account originalAccount = [SELECT Id, Name FROM Account WHERE Name = 'Original Account' LIMIT 1];
        
        // Call duplicateRecords method
        Test.startTest();
        Map<String, List<Account>> duplicateDetails = DuplicateAccountController.duplicateRecords(originalAccount.Id);
        Test.stopTest();
        
        // Verify the results
        System.assert(duplicateDetails.containsKey('Original'));
        System.assert(duplicateDetails.containsKey('Duplicate'));
        
        List<Account> originalAccounts = duplicateDetails.get('Original');
        List<Account> duplicateAccounts = duplicateDetails.get('Duplicate');
       
    }
}