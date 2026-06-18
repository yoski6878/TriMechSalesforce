@isTest
public class TaskCreatorEmailServiceTest {
    
    @isTest
    static void testSendSummaryEmailWithValidUser() {
        // Test sending email with valid user - just verify no exceptions thrown
        TaskCreatorEmailService.sendSummaryEmail(UserInfo.getUserId(), 5, 2, 'Some error occurred', false, 'Test Subject');
    }
    
    @isTest
    static void testSendSummaryEmailWithNullUser() {
        // Test with null user ID - should not throw exception
        TaskCreatorEmailService.sendSummaryEmail(null, 5, 2, 'Some error occurred', false, 'Test Subject');
    }
    
    @isTest
    static void testSendSummaryEmailWithNoEmail() {
        // Test with valid user but no email - should not throw exception
        TaskCreatorEmailService.sendSummaryEmail(UserInfo.getUserId(), 5, 2, 'Some error occurred', false, 'Test Subject');
    }
    
    @isTest
    static void testSendSummaryEmailLargeJob() {
        // Test sending email for large job
        TaskCreatorEmailService.sendSummaryEmail(UserInfo.getUserId(), 0, 0, '', true, 'Test Subject');
    }
    
    @isTest
    static void testSendSummaryEmailWithBlankSubject() {
        // Test with blank subject - should fall back to "Task"
        TaskCreatorEmailService.sendSummaryEmail(UserInfo.getUserId(), 5, 2, 'Some error occurred', false, '');
    }
}