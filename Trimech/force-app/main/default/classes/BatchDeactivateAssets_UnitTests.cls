@isTest
private class BatchDeactivateAssets_UnitTests {
  
    @isTest static void testBatch() {
   
      Account a = new Account(Name = 'Test Account 1');
      insert a;

      Asset a1 = new Asset(Name = 'Asset 1', Status = 'Active', AccountId = a.Id, UsageEndDate = system.Today().addDays(-1));
      Asset a2 = new Asset(Name = 'Asset 2', Status = 'Active', AccountId = a.Id, UsageEndDate = system.Today().addDays(2));
      List<Asset> aList = new List<Asset>{a1,a2};
      insert aList;
      
      Test.startTest();
      BatchDeactivateAssets.scheduleMe();
      BatchDeactivateAssets sch = new BatchDeactivateAssets();
      Database.executeBatch(sch, 200);
      Test.stopTest();

      for(Asset ass : [SELECT Id, Status FROM Asset WHERE Id = :a1.Id]){
        System.assertEquals('Inactive', ass.Status);
      }
    }
}