/**************************************************************
 * This test class is used to test the trigger and class
 * for the OpportunityLineItem object.
 * 
 ***************************************************************/
@isTest
private class OpportunityLineItem_Trigger_UnitTests {
    
    @isTest (SeeAllData=true)
    private static void testUpdate(){
        
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        Id pricebookId = Test.getStandardPricebookId();
        
        Product_Category__c pc = new Product_Category__c(Name = 'Test Category');
        
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true, Corresponding_Product_Category__c = pc.Id);
        insert prod;
        
        PriceBookEntry pbe = new PriceBookEntry(Pricebook2Id = pricebookId, Product2Id = prod.Id, IsActive = true, UnitPrice = 200.00, Purchase_Price__c = 10.00);
        insert pbe;
            
        Opportunity o = new Opportunity(Name = 'Opp 1', CloseDate = System.today(), StageName = 'Qualified', AccountId = a.Id);
        insert o;
        
        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, UnitPrice = 200.00, Quantity = 1);
        insert oli;
            

    }
}