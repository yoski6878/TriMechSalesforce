@isTest
public class TaskCreatorQueueableTest {
    @isTest
    static void testExecute_withValidAndInvalidRecords() {
        // Create test users
        User u = [SELECT Id FROM User WHERE Profile.Name = 'Standard User' LIMIT 1];
        // Prepare valid and invalid records
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        // Valid record
        records.add(new Map<String, Object>{
            'contactId' => '003000000000000AAA',
            'accountId' => '001000000000000AAA',
            'ownerId' => u.Id,
            'subject' => 'Test Subject',
            'dueDate' => '2026-03-10',
            'type' => 'Call'
        });
        // Invalid ownerId
        records.add(new Map<String, Object>{
            'contactId' => '003000000000001AAA',
            'accountId' => '001000000000001AAA',
            'ownerId' => 'invalid',
            'subject' => 'Test Subject',
            'dueDate' => '2026-03-10',
            'type' => 'Call'
        });
        // Invalid dueDate
        records.add(new Map<String, Object>{
            'contactId' => '003000000000002AAA',
            'accountId' => '001000000000002AAA',
            'ownerId' => u.Id,
            'subject' => 'Test Subject',
            'dueDate' => 'not-a-date',
            'type' => 'Call'
        });
        Test.startTest();
        TaskCreatorQueueable job = new TaskCreatorQueueable(records, u.Id);
        System.enqueueJob(job);
        Test.stopTest();
        // Assert that the valid task was created
        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE Subject = 'Test Subject'];
        System.assertEquals(1, tasks.size(), 'One valid task should be created');
    }
}