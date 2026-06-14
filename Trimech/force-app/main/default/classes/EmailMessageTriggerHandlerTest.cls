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
    
        @isTest
    static void testTriggerFlowCoverage() {

        Account acc = new Account(Name = 'Account A');
        Account acc2 = new Account(Name = 'Account B');
        insert new List<Account>{ acc, acc2 };

        Contact con1 = new Contact(LastName='Primary', Email='p1@test.com', AccountId=acc.Id);
        Contact con2 = new Contact(LastName='RoleMatch', Email='cc@test.com', AccountId=acc.Id);
        Contact con3 = new Contact(LastName='WrongAcc', Email='other@test.com', AccountId=acc2.Id);
        insert new List<Contact>{ con1, con2, con3 };

        Case c = new Case(
            Subject='Trigger Test Case',
            AccountId=acc.Id,
            ContactId=con1.Id,
            Status='New',
            Origin='Phone'
        );
        insert c;

        // Create EmailMessage record to trigger logic
        EmailMessage em = new EmailMessage(
            RelatedToId = c.Id,
            Subject = 'Test Email',
            FromAddress = 'sender@test.com',
            ToAddress = 'receiver@test.com',
            CcAddress ='cc@test.com;missing@test.com,other@test.com',
            Status = '0'
        );

        Test.startTest();
        insert em; // <-- Trigger fires here
        Test.stopTest();

    }

    @isTest
    static void testNoOpScenario() {
        Test.startTest();
        EmailMessage emptyEmail = new EmailMessage(
            Subject = 'No Related Case',
            FromAddress = 'x@test.com',
            ToAddress='y@test.com',
            Status='0'
        );
        insert emptyEmail; // should exit early in handler
        Test.stopTest();
    }

}