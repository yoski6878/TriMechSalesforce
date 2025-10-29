global class OpportunityReassignmentScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Run the batch with 200 records per chunk
        Database.executeBatch(new NeglectedLeadOppReassignmentBatch(), 200);
    }
}