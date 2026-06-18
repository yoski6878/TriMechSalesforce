@isTest
private class BatchNeglectedLeadUnitTests {
  
    @isTest static void testBatch() {
   
      Account a = new Account(Name = 'Test Account 1');
      insert a;

      Opportunity o = new Opportunity(Name = 'Lead', AccountId = a.Id, StageName = 'New', CloseDate = system.Today());
      insert o;
      
      Task t = new Task(Subject = 'Activity', WhatId = o.Id, Status = 'Completed', ActivityDate = system.Today().addDays(-3));
      insert t;
      
      Test.startTest();
      BatchNeglectedLead.scheduleMe();
      BatchNeglectedLead sch = new BatchNeglectedLead();
      Database.executeBatch(sch, 1);
      Test.stopTest();

      for(Opportunity opp : [SELECT Id, StageName FROM Opportunity WHERE Id = :o.Id]){
        System.assertEquals('Neglected', opp.StageName);
      }
    }
}