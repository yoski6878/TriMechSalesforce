@isTest
public class DuplicateContactControllerTest {
    @testSetup
    static void setup() {
        // Create original account
        Contact originalAccount = new Contact(
            LastName = 'Original Account',
            email = 'test@testing.com.invalid'
            
        );
        insert originalAccount;
        
        // Create duplicate account
        Contact duplicateAccount = new Contact(
            LastName = 'Duplicate Account'
            
        );
        insert duplicateAccount;
    }

    @isTest
    static void testSendEmail() {
        // Get accounts
        Contact originalAccount = [SELECT Id, Name FROM Contact WHERE Name = 'Original Account' LIMIT 1];
        Contact duplicateAccount = [SELECT Id, Name FROM Contact WHERE Name = 'Duplicate Account' LIMIT 1];
        
        // Create JSON strings
        String originalJson = JSON.serialize(new List<Contact> { originalAccount });
        String duplicateJson = JSON.serialize(new List<Contact> { duplicateAccount });
        
        // Call sendemail method
        Test.startTest();
        DuplicateContactController.sendemail('Test notes', originalAccount.Id, originalJson, duplicateJson);
        Test.stopTest();
        
        // Verify accounts were updated

       
    }
    
    @isTest
    static void testDuplicateRecords() {
        // Get original account
        Contact originalAccount = [SELECT Id, Name FROM Contact WHERE Name = 'Original Account' LIMIT 1];
        
        // Call duplicateRecords method
        Test.startTest();
        Map<String, List<Contact>> duplicateDetails = DuplicateContactController.duplicateRecords(originalAccount.Id);
        Test.stopTest();
        
  
       
    }
}