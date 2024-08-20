/**************************************************************
 * This test class is used to test the trigger and class
 * for the Opportunity object.
 * 
 ***************************************************************/
@isTest
private class Opportunity_Trigger_UnitTests {
    
    @isTest
    private static void testUpdate(){
        
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        Pricebook2 customPB = new Pricebook2(Name = 'Custom PB', IsActive = true);
        insert customPB;
        
        Product_Group__c g1 = new Product_Group__c(Name = 'Software', Default_Price_Book__c = String.valueOf(Test.getStandardPricebookId()));
        Product_Group__c g2 = new Product_Group__c(Name = 'Hardware', Default_Price_Book__c = String.valueOf(customPB.Id));
        insert new Product_Group__c[]{g1,g2};
            
        Opportunity o1 = new Opportunity(Name = 'Opp 1', Product_Group__c = g1.Id, CloseDate = System.today(), StageName = 'Qualified', AccountId = a.Id);
        Opportunity o2 = new Opportunity(Name = 'Opp 2', Product_Group__c = g2.Id, CloseDate = System.today(), StageName = 'New', AccountId = a.Id, Loss_Reason__c = 'Other');
        insert new Opportunity[]{o1,o2};
            
        //System.assertEquals(2,[SELECT Id FROM Opportunity WHERE Pricebook2Id != null].size());
        
        o1.Product_Group__c = g2.Id;
        o2.Product_Group__c = null;
        o2.StageName = 'Qualified';
        update new Opportunity[]{o1,o2};
            
        //System.assertEquals(1,[SELECT Id FROM Opportunity WHERE Pricebook2Id = :customPB.Id].size());
        
        o2.StageName = 'Closed Lost';
        update new Opportunity[]{o2};
    }
}