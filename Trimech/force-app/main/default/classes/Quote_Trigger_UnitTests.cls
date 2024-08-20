/**************************************************************
 * This test class is used to test the trigger and class
 * for the Quote object.
 * 
 ***************************************************************/
@isTest
public class Quote_Trigger_UnitTests {
  
  @isTest
  public static void testSetAccount(){
   
            
        Account a1 = new Account(Name = 'Eustace Consulting');
        insert new Account[]{a1};
        
        Opportunity o1 = new Opportunity(Name = 'Test', StageName = 'Qualified', CloseDate = system.Today(), AccountId = a1.Id);
        insert new Opportunity[]{o1};
        
        Quote q1 = new Quote(Name = 'Test', OpportunityId = o1.Id);
        insert new Quote[]{q1};
            
        //System.assertEquals(a1.Id, q1.Account__c);            

  }
}