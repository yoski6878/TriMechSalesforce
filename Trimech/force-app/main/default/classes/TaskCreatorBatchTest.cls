@isTest
public class TaskCreatorBatchTest {
    @isTest static void testBatchInsert() {
        List<Map<String, Object>> tasks = new List<Map<String, Object>>();
        for (Integer i = 0; i < 50; i++) {
            Map<String, Object> row = new Map<String, Object>{
                'contactId' => null,
                'accountId' => null,
                'ownerId' => UserInfo.getUserId(),
                'subject' => 'Test Task ' + i,
                'dueDate' => String.valueOf(Date.today()),
                'type' => 'Call'
            };
            tasks.add(row);
        }
        Test.startTest();
        Database.executeBatch(new TaskCreatorBatch(tasks, UserInfo.getUserId(), null), 50);
        Test.stopTest();
        System.assertEquals(50, [SELECT count() FROM Task WHERE Subject LIKE 'Test Task%']);
    }
}