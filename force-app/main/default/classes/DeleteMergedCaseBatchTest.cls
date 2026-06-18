/**
* @File Name : DeleteMergedCaseBatchTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 18, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 18, 2025 |   | Initial Version
**/

@isTest
public class DeleteMergedCaseBatchTest {
    
    @testSetup
    static void setupTestData() {

		Account newAccount = new Account(Name = 'Test Account');
        insert newAccount; 

        Case c1 = new Case(
            Subject = 'Test Case 1',
            Status = 'New',
            AccountId = newAccount.Id
        );

        Case c2 = new Case(
            Subject = 'Test Case 2',
            Status = 'New',
            AccountId = newAccount.Id
        );

		insert new List<Case> {c1,c2};

		Database.merge(c1, c2);
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        DeleteMergedCaseBatch batchJob = new DeleteMergedCaseBatch();
        Database.ExecuteBatch(batchJob);
        Test.stopTest();
    }

	@isTest
    static void testBatchExecutionThroughScheduler() {
        Test.startTest();
        new DeleteMergeCasesScheduler().execute(null);
        Test.stopTest();
    }
}