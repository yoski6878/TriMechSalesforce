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
public class CaseGenerationFormControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test Accounts
        Account account1 = new Account(Name = 'Test Company');
        insert account1;

        // Create test Assets
        Asset asset1 = new Asset(Name = 'Test Asset 1', SerialNumber = '12345', AccountId = account1.Id);
        insert asset1;

		Asset asset2 = new Asset(Name = 'Test Asset 2', SerialNumber = '12345', AccountId = account1.Id);
        insert asset2;

		Asset asset3 = new Asset(Name = 'Test Asset 3', SerialNumber = '123456', AccountId = account1.Id);
        insert asset3;
        // Create test Contacts
        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'test@example.com', AccountId = account1.Id);
        insert contact1;

        // Create test Product
        Product2 product = new Product2(Name = 'Test Product', ProductCode = 'PROD123', IsActive = true);
        insert product;


        // Create Queue Group
        Group queue = new Group(Name = 'TestQueue', DeveloperName = 'TestQueue', Type = 'Queue');
        insert queue;

    }

    @isTest
    static void testGenerateCase_Success() {
        // Prepare test data

		CaseGenerationFormController.caseRecordWrapper caseWrapper = new CaseGenerationFormController.caseRecordWrapper();
		caseWrapper.FirstName = 'Jane';
		caseWrapper.LastName = 'Doe';
		caseWrapper.CompanyName = 'Test Company';
		caseWrapper.phoneNumber = '123-456-7890';
		caseWrapper.email = 'test@example.com';
		caseWrapper.productName = 'Test Product';
		caseWrapper.softwareVersion = '1.0';
		caseWrapper.serialNumber = '12345';
		caseWrapper.subject = 'Test Subject';
		caseWrapper.priority = 'High';
		caseWrapper.description = 'Test Description';
		// caseWrapper.contentDocumentId = '12345';
		// caseWrapper.contentVersionId = '67890';
		// caseWrapper.encryptionToken = 'abcdef';

        String caseRecord = JSON.serialize(caseWrapper);
		
		CaseGenerationFormController.caseRecordWrapper caseWrapper2 = new CaseGenerationFormController.caseRecordWrapper();
		caseWrapper2.FirstName = 'Jane';
		caseWrapper2.LastName = 'Doe';
		caseWrapper2.CompanyName = 'Testing23 Company';
		caseWrapper2.phoneNumber = '123333-7890';
		caseWrapper2.email = 'test@example.com.invalid';
		caseWrapper2.productName = 'Tester Product';
		caseWrapper2.softwareVersion = '1.0';
		caseWrapper2.serialNumber = '123456';
		caseWrapper2.subject = 'Test Subject';
		caseWrapper2.priority = 'High';
		caseWrapper2.description = 'Test Description';
		// caseWrapper2.contentDocumentId = '123456';
		// caseWrapper2.contentVersionId = '67892340';
		// caseWrapper2.encryptionToken = 'abcdef';

        String caseRecord2 = JSON.serialize(caseWrapper2); 
		
        // Call the method
        Test.startTest();
		String result = CaseGenerationFormController.generateCase(caseRecord);
        String result2 = CaseGenerationFormController.generateCase(caseRecord2);
        Test.stopTest();

    }

    @isTest
    static void testGenerateCase_InvalidSerialNumber() {
        // Prepare test data with an invalid serial number
		CaseGenerationFormController.caseRecordWrapper caseWrapper = new CaseGenerationFormController.caseRecordWrapper();
		
		caseWrapper.FirstName = 'Invalid';
		caseWrapper.LastName = 'Serial';
		caseWrapper.CompanyName = 'Test Company';
		caseWrapper.phoneNumber = '123-456-7890';
		caseWrapper.email = 'invalid@example.com';
		caseWrapper.productName = 'Test Product';
		caseWrapper.softwareVersion = '1.0';
		caseWrapper.serialNumber = 'InvalidSerial';
		caseWrapper.subject = 'Invalid Serial Test';
		caseWrapper.priority = 'Low';
		caseWrapper.description = 'Testing invalid serial number';
		// caseWrapper.contentDocumentId = '12345';
		// caseWrapper.contentVersionId = '67890';
		// caseWrapper.encryptionToken = 'abcdef';

		String caseRecord = JSON.serialize(caseWrapper);


		CaseGenerationFormController.caseRecordWrapper caseWrapper2 = new CaseGenerationFormController.caseRecordWrapper();
		
		caseWrapper2.FirstName = 'Invalid';
		caseWrapper2.LastName = 'Serial';
		caseWrapper2.CompanyName = 'Test Company';
		caseWrapper2.phoneNumber = '123-456-7890';
		caseWrapper2.email = 'invalid@example.com';
		caseWrapper2.productName = 'Test Product';
		caseWrapper2.softwareVersion = '1.0';
		caseWrapper2.subject = 'Invalid Serial Test';
		caseWrapper2.priority = 'Low';
		caseWrapper2.description = 'Testing invalid serial number';
		// caseWrapper2.contentDocumentId = '12345';
		// caseWrapper2.contentVersionId = '67890';
		// caseWrapper2.encryptionToken = 'abcdef';

		String caseRecord2 = JSON.serialize(caseWrapper2);

        // Call the method
        Test.startTest();
		String result = CaseGenerationFormController.generateCase(caseRecord);
        String result2 = CaseGenerationFormController.generateCase(caseRecord2);
        Test.stopTest();

    }

    @isTest
    static void testGetCustomPickListValues_ValidField() {
        Test.startTest();
        List<Map<String, String>> picklistValues = CaseGenerationFormController.getCustomPickListValues('Case', 'Status');
        Test.stopTest();
    }

}