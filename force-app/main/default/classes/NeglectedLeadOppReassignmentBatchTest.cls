@isTest
private class NeglectedLeadOppReassignmentBatchTest {
      
    @isTest static void testBatch() {
   
      Account a = new Account(Name = 'Test Account 1');
      insert a;

       List<Opportunity> opplist = new List<Opportunity>();

        Opportunity o = new Opportunity(Name = 'Lead', AccountId = a.Id, StageName = 'New', CloseDate = system.Today());
        opplist.add(o);
        Opportunity o2 = new Opportunity(Name = 'Lead', AccountId = a.Id, StageName = 'New', CloseDate = system.Today());
        opplist.add(o2);
        Opportunity o3 = new Opportunity(Name = 'Lead', AccountId = a.Id, StageName = 'Neglected', CloseDate = system.Today());
        opplist.add(o3);
        Opportunity o4 = new Opportunity(Name = 'Lead', AccountId = a.Id, StageName = 'Neglected',LSC_Campaign__c='tradeshow', CloseDate = system.Today());
        opplist.add(o4);
        
        insert opplist;
      
      Task t = new Task(Subject = 'Activity', WhatId = o.Id, Status = 'Completed', ActivityDate = system.Today().addDays(-3));
      insert t;
        
      Task t2 = new Task(Subject = 'Activity', WhatId = o2.Id, Status = 'Completed', ActivityDate = system.Today().addDays(-90));
      insert t2;
      
      Test.startTest();
         // NeglectedLeadOppReassignmentBatch sch = new NeglectedLeadOppReassignmentBatch();
          // Database.executeBatch(sch, 1);
       		String cronExp = '0 0 0 * * ?';
           String jobId = System.schedule('Test_Opportunity_Reassignment_Scheduler', cronExp, new OpportunityReassignmentScheduler());
        
        Date mon = Date.newInstance(2025, 9, 29); // Monday
        Date fri = Date.newInstance(2025, 10, 3); // Friday
        Integer days = NeglectedLeadOppReassignmentBatch.businessDaysBetween(mon, fri); 

      Test.stopTest();
        

    }

}