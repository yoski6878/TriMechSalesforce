/**************************************************************
 * This test class is used to test the trigger and class
 * for the Opportunity object.
 **************************************************************/
@isTest
private class Opportunity_Trigger_UnitTests {
    
    @isTest
    private static void testUpdate() {
        
        // Create test account
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
		Schema.location lc = new Schema.location (Name='Test', LocationType = 'Site');
		insert lc;        
        Schema.Address addr = new Schema.Address( ParentId = lc.Id, LocationType = 'Site',Account__c = a.Id);
        insert addr;
        
        // Create pricebooks
        Pricebook2 customPB = new Pricebook2(Name = 'Custom PB', IsActive = true);
        insert customPB;
        
        // Create product groups with associated pricebooks
        Product_Group__c g1 = new Product_Group__c(Name = 'Software', Default_Price_Book__c = String.valueOf(Test.getStandardPricebookId()));
        Product_Group__c g2 = new Product_Group__c(Name = 'Hardware', Default_Price_Book__c = String.valueOf(customPB.Id));
        insert new Product_Group__c[]{g1, g2};
            
        // Create opportunities
        Opportunity o1 = new Opportunity(
            Name = 'Opp 1', 
            Product_Group__c = g1.Id, 
            CloseDate = System.today(), 
            StageName = 'Qualified', 
            AccountId = a.Id
        );
        Opportunity o2 = new Opportunity(
            Name = 'Opp 2', 
            Product_Group__c = g2.Id, 
            CloseDate = System.today(), 
            StageName = 'New', 
            AccountId = a.Id, 
            Loss_Reason__c = 'Other'
        );
        insert new Opportunity[]{o1, o2};
            
        // Validate that the Pricebook is assigned correctly
        System.assertEquals(2, [SELECT Id FROM Opportunity WHERE Pricebook2Id != null].size());
        
        // Update opportunities
        o1.Product_Group__c = g2.Id;
        o2.Product_Group__c = null; // Simulate removing the product group
        o2.StageName = 'Qualified';
        update new Opportunity[]{o1, o2};
        
        // Validate updated Pricebook2Id values
        //System.assertEquals(1, [SELECT Id FROM Opportunity WHERE Pricebook2Id = :customPB.Id].size());
        
        // Test stage update to 'Closed Lost' and ensure required fields are set
        o2.StageName = 'Closed Lost';
        o2.Actual_Close_Date__c = System.today().addDays(15);
        o2.CloseDate = System.today().addDays(15); // Ensure CloseDate is valid for this stage
        update new Opportunity[]{o2};
        
        // Validate the update success
        Opportunity updatedOpp = [SELECT StageName, CloseDate FROM Opportunity WHERE Id = :o2.Id];
        System.assertEquals('Closed Lost', updatedOpp.StageName);
        System.assertEquals(System.today().addDays(15), updatedOpp.CloseDate);
    }
}