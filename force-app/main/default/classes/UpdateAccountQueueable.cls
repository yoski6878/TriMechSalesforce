public class UpdateAccountQueueable implements Queueable { 

    public List<Account> acctsToProcess;

    public UpdateAccountQueueable(List <Account> accts) {
        acctsToProcess = accts;
    }

    public void execute(QueueableContext context) {
        system.debug(acctsToProcess.size());
        Account acct = acctsToProcess.remove(0);
        update acct;
        integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport(); 
        if (!acctsToProcess.isEmpty()) {
            //Call queuable again with modified set of Ids
            UpdateAccountQueueable q = new UpdateAccountQueueable(acctsToProcess);
            if (!Test.isRunningTest()) System.enqueueJob(q);
        }
    }
}