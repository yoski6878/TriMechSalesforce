/**************************************************************
 * This test class is used to test the trigger and class
 * for the Order object.
 * 
 ***************************************************************/
@isTest
private class Order_Trigger_UnitTests {
    
    @isTest
    private static void testUpdate(){
        
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        Opportunity o1 = new Opportunity(Name = 'Opp 1', CloseDate = System.today(), StageName = 'Qualified', AccountId = a.Id);
        Opportunity o2 = new Opportunity(Name = 'Opp 2', CloseDate = System.today(), StageName = 'Qualified', AccountId = a.Id);
        insert new Opportunity[]{o1,o2};

        Order ord1 = new Order(AccountId = a.Id, OpportunityId = o1.Id, EffectiveDate = System.today(), Status = 'Draft', Draft__c = 'No');
        Order ord2 = new Order(AccountId = a.Id, OpportunityId = o2.Id, EffectiveDate = System.today(), Status = 'Draft', Draft__c = 'Yes');
        insert new Order[]{ord1,ord2};  
        
        ord2.Draft__c = 'No';
        update new Order[]{ord2};
    }
}