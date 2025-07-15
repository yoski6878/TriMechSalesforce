@isTest
private class EmailMessageTriggerHandlerTest {
    @isTest
    static void testSetEmailsExternallyVisible() {
        // Create a test case
        Case testCase = new Case(Status = 'New', Subject = 'Test Case');
        insert testCase;

        // Create an EmailMessage related to the case
        EmailMessage testEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Test Email',
            TextBody = 'This is a test email'
        );

        Test.startTest();
        insert testEmail;
        Test.stopTest();

        // Retrieve the inserted email message
        EmailMessage insertedEmail = [SELECT Id, IsExternallyVisible FROM EmailMessage WHERE Id = :testEmail.Id];

        // Assert that IsExternallyVisible is set to true
        System.assertEquals(true, insertedEmail.IsExternallyVisible);
    }
}