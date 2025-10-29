public class BatchNeglectedLead implements Database.Batchable<sObject>, Schedulable {
    
    public static void scheduleMe() {

        BatchNeglectedLead sch = new BatchNeglectedLead();
        
        /* Luigi */
        /* Edited the cron to run from MON-FRI */
        /* String cron = '0 0 23 * * ?'; ** Luigi */ 
        String cron = '0 0 23 ? * MON-FRI';
        String title = 'Neglected Lead Status';
        if(Test.isRunningTest()) title = 'Test Update Neglected Status Test';
        System.schedule(title, cron, sch);
    }
    
    public void execute(SchedulableContext sc){
        BatchNeglectedLead sch = new BatchNeglectedLead();
        Database.executeBatch(sch, 20);
    }
  
    public Database.QueryLocator start(Database.BatchableContext BC) {
    
    //Formula to calculate Days uses system fields that cant be set for test class
    if(Test.isRunningTest()) return Database.getQueryLocator([SELECT Id, 
                                            StageName
                                    FROM Opportunity 
                                    WHERE /*Days_Since_Last_Activity__c >= 0 AND */StageName = 'New']);
    else return Database.getQueryLocator([SELECT Id, 
                                            StageName
                                    FROM Opportunity 
                                    WHERE Days_Since_Last_Activity__c >= 1 AND StageName = 'New']);                                     
    }

    public void execute(Database.BatchableContext BC, List<Opportunity> scope) {

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for(Opportunity o : scope){
            oppsToUpdate.add(new Opportunity(Id = o.Id, StageName = 'Neglected', Neglected_date__c = Date.Today()));
        }

        if(!oppsToUpdate.isEmpty()) update oppsToUpdate;
    }
  
    public void finish(Database.BatchableContext BC){}  

}