@isTest
private class SetUrgentPriorityOnCaseTest {
    @isTest
    static void testNoFalsePositiveUrgent() {
        Case testCase = new Case(Subject = 'Fortus Negative Test', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        EmailMessage email = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'This is an insurgent update',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0',
            Headers = 'X-Priority: 3\nImportance: Normal'
        );
        insert email;

        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Medium', updatedCase.Priority, 'Case priority should remain Medium for non-urgent word');
    }
    
    @isTest
    static void testUrgentByHeader() {
        // Create a Case with default values
        Case testCase = new Case(Subject = 'Fortus Header Test', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        // Create EmailMessage with URGENT headers
        EmailMessage urgentEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Normal Subject',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0', // Inbound
            Headers = 'X-Priority: 1\nImportance: High'
        );
        insert urgentEmail;

        // Verify Case was updated
        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Urgent', updatedCase.Priority, 'Case priority should be Urgent for urgent email');
    }

    @isTest
    static void testUrgentBySubject() {
        Case testCase = new Case(Subject = 'Fortus Subject Test', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        EmailMessage urgentEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Please respond URGENT',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0',
            Headers = 'X-Priority: 3\nImportance: Normal'
        );
        insert urgentEmail;

        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Urgent', updatedCase.Priority, 'Case priority should be Urgent for subject keyword');
    }

    @isTest
    static void testNormalEmail() {
        Case testCase = new Case(Subject = 'Fortus Normal Case', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        EmailMessage normalEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'Just a normal email',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0',
            Headers = 'X-Priority: 3\nImportance: Normal'
        );
        insert normalEmail;

        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Medium', updatedCase.Priority, 'Case priority should remain Medium for normal email');
    }

    @isTest
    static void testUrgentByHeaderFallback() {
        // Header contains 'high' in a non-standard way
        Case testCase = new Case(Subject = 'Fortus Header Fallback', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        EmailMessage urgentEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'No urgent keyword',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0',
            Headers = 'SomeCustomHeader: totallyhighvalue\nAnotherHeader: notimportant'
        );
        insert urgentEmail;

        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Urgent', updatedCase.Priority, 'Case priority should be Urgent for fallback header logic');
    }

    @isTest
    static void testUrgentByCriticalSubject() {
        Case testCase = new Case(Subject = 'Fortus Critical Subject Test', Origin = 'Email', Priority = 'Medium', Status = 'New', Issue__c = 'Fortus');
        insert testCase;

        EmailMessage criticalEmail = new EmailMessage(
            ParentId = testCase.Id,
            Subject = 'This is CRITICAL',
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Status = '0',
            Headers = 'X-Priority: 3\nImportance: Normal'
        );
        insert criticalEmail;

        Case updatedCase = [SELECT Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Urgent', updatedCase.Priority, 'Case priority should be Urgent for critical subject keyword');
    }

}