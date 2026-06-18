public class InsertLeadAssignmentProcessQueueable implements Queueable {
    
    public List<Lead_Assignment_Process__c> lapsToProcess;
    
    public InsertLeadAssignmentProcessQueueable(List<Lead_Assignment_Process__c> laps) {
        lapsToProcess = laps;
    }

    public void execute(QueueableContext context) {
        system.debug(lapsToProcess.size());
        insert lapsToProcess;
        /*Lead_Assignment_Process__c lap = lapsToProcess.remove(0);
        insert lap;
        if (!lapsToProcess.isEmpty()) {
            //Call queuable again with modified set of Ids
            InsertLeadAssignmentProcessQueueable q = new InsertLeadAssignmentProcessQueueable(lapsToProcess);
            if (!Test.isRunningTest()) System.enqueueJob(q);
            //System.enqueueJob(q);
        }*/
    }
}