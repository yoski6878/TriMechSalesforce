public class BatchDeactivateAssets implements Database.Batchable<sObject>, Schedulable {
    
    public static void scheduleMe() {

        BatchDeactivateAssets sch = new BatchDeactivateAssets();
        String cron = '0 0 1 * * ?';
        String title = 'Deactivate Assets';
        if(Test.isRunningTest()) title = 'Test Deactivate Assets Test';
        System.schedule(title, cron, sch);
    }
    
    public void execute(SchedulableContext sc){
        BatchDeactivateAssets sch = new BatchDeactivateAssets();
        Database.executeBatch(sch, 50);
    }
  
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
    return Database.getQueryLocator([SELECT Id, 
                                            Status, 
                                            Status_Calculated__c,
                                            UsageEndDate
                                    FROM Asset 
                                    WHERE Status != '']);
    }

    public void execute(Database.BatchableContext BC, List<Asset> scope) {

        List<Asset> assetsToUpdate = new List<Asset>();
        for(Asset a : scope){
            if(a.Status_Calculated__c != a.Status){
                assetsToUpdate.add(new Asset(Id = a.Id, Status = a.Status_Calculated__c));
            }
        }

        if(!assetsToUpdate.isEmpty()) update assetsToUpdate;
    }
  
    public void finish(Database.BatchableContext BC){}  
}