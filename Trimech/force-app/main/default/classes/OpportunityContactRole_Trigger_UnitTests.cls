/**************************************************************
 * This test class is used to test the trigger and class
 * for the OpportunityContactRole object.
 * 
 ***************************************************************/
@isTest
public class OpportunityContactRole_Trigger_UnitTests {
    
    @isTest
    public static void afterInsertUpdateTest(){
    
    Account a1 = new Account(Name = 'Test');
    insert new Account[]{a1};
    
    Contact c1 = new Contact(FirstName = 'Test1', LastName = 'Test1');
    Contact c2 = new Contact(FirstName = 'Test2', LastName = 'Test2');
    insert new Contact[]{c1,c2};
    
    Opportunity o1 = new Opportunity(Name = 'Test', AccountId = a1.Id, StageName = 'New', CloseDate = System.today());
    insert new Opportunity[]{o1};
    
    OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = o1.Id, ContactId = c1.Id, IsPrimary = true);
    OpportunityContactRole ocr2 = new OpportunityContactRole(OpportunityId = o1.Id, ContactId = c2.Id);
    insert new OpportunityContactRole[]{ocr1,ocr2};
       
    ocr2.IsPrimary = true;
    update ocr2;
    
    delete ocr2;
    
    }
    
}