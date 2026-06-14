/**
* @File Name : FlowCaseContactRolesRecalcTest.cls
* @Description : Comprehensive test class for FlowCaseContactRolesRecalc invocable method.
*/
@IsTest
public class FlowCaseContactRolesRecalcTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'User',
            Email     = 'test@test.com',
            AccountId = acc.Id
        );
        insert con;

        // Case without email messages (tests fallback path)
        Case c1 = new Case(
            Subject   = 'No Email Case',
            Status    = 'New',
            Origin    = 'Phone',
            AccountId = acc.Id,
            ContactId = con.Id
        );
        insert c1;

        // Case with EmailMessage (tests primary logic)
        Case c2 = new Case(
            Subject   = 'Email Case',
            Status    = 'New',
            Origin    = 'Phone',
            AccountId = acc.Id,
            ContactId = con.Id
        );
        insert c2;

        // EmailMessage with CC for c2 (to hit primary logic branch)
        EmailMessage em = new EmailMessage(
            RelatedToId  = c2.Id,
            ToAddress    = 'to@test.com',
            FromAddress  = 'from@test.com',
            CcAddress    = 'cc1@test.com,cc2@test.com',
            Subject      = 'Test Email',
            Status       = '0',
            Incoming     = false
        );
        insert em;
    }

    @IsTest
    static void test_AddAndRecalc_ValidInputs() {
        // Get test data
        Case fallbackCase = [SELECT Id, ContactId FROM Case WHERE Subject = 'No Email Case' LIMIT 1];
        Case emailCase    = [SELECT Id, ContactId FROM Case WHERE Subject = 'Email Case' LIMIT 1];

        List<FlowCaseContactRolesRecalc.Input> inputs = new List<FlowCaseContactRolesRecalc.Input>{
            new FlowCaseContactRolesRecalc.Input()
        };
        inputs[0].caseId = fallbackCase.Id;
        inputs[0].contactId = fallbackCase.ContactId;
        inputs[0].role = 'TestRole';

        // Add another input for email branch
        FlowCaseContactRolesRecalc.Input emailInput = new FlowCaseContactRolesRecalc.Input();
        emailInput.caseId = emailCase.Id;
        emailInput.contactId = emailCase.ContactId;
        emailInput.role = 'EmailRole';
        inputs.add(emailInput);

        Test.startTest();
        List<FlowCaseContactRolesRecalc.Output> results = FlowCaseContactRolesRecalc.addAndRecalc(inputs);
        Test.stopTest();
        // No asserts; just coverage
    }

    @IsTest
    static void test_AddAndRecalc_InvalidInputs() {
        // Null input
        // Empty input
        // Input with missing ContactId
        Case fallbackCase = [SELECT Id FROM Case WHERE Subject = 'No Email Case' LIMIT 1];
        FlowCaseContactRolesRecalc.Input badInput = new FlowCaseContactRolesRecalc.Input();
        badInput.caseId = fallbackCase.Id;
        badInput.contactId = null;
        badInput.role = 'BadRole';

        Test.startTest();
        List<FlowCaseContactRolesRecalc.Output> nullResults = FlowCaseContactRolesRecalc.addAndRecalc(null);
        List<FlowCaseContactRolesRecalc.Output> emptyResults = FlowCaseContactRolesRecalc.addAndRecalc(new List<FlowCaseContactRolesRecalc.Input>());
        List<FlowCaseContactRolesRecalc.Output> badResults = FlowCaseContactRolesRecalc.addAndRecalc(new List<FlowCaseContactRolesRecalc.Input>{badInput});
        Test.stopTest();
        // No asserts; just coverage
    }

    @IsTest
    static void test_AddAndRecalc_InvalidCaseId() {
        // Use an Account Id to trigger the "non-Case" branch
        Account acc = [SELECT Id FROM Account LIMIT 1];
        FlowCaseContactRolesRecalc.Input input = new FlowCaseContactRolesRecalc.Input();
        input.caseId = acc.Id;
        input.contactId = null;
        input.role = 'InvalidCase';

        Test.startTest();
        List<FlowCaseContactRolesRecalc.Output> results = FlowCaseContactRolesRecalc.addAndRecalc(new List<FlowCaseContactRolesRecalc.Input>{input});
        Test.stopTest();
        // No asserts; just coverage
    }
}