/**************************************************************
 * This test class is used to test the trigger and class
 * for the Contact object.
 * 
 ***************************************************************/
@isTest
public class Contact_Trigger_UnitTests {
    
    @isTest
    public static void testinsert(){
        
        Account a = new Account(Name = 'Test Account');
        insert new Account[]{a};
        
        Contact c = new Contact(LastName = 'Test', AccountId = a.Id);
        insert new Contact[]{c};
        
        c.LastName = 'TestTest';
        update c;
        
    }
   
}