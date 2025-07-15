@isTest
private class QuoteLineItem_Trigger_Tests {
    
    @isTest (SeeAllData=true)
    private static void testUpdate() {
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        Id pricebookId = Test.getStandardPricebookId();
        
        Product_Category__c pc = new Product_Category__c(Name = 'Test Category');
        
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true, CurrencyIsoCode = 'USD', Description = 'This is a test product.', Corresponding_Product_Category__c = pc.Id);
        Product2 prod2 = new Product2(Name = 'Test Product', IsActive = true, CurrencyIsoCode = 'USD', Description = 'This is a test product.', Corresponding_Product_Category__c = pc.Id);
        insert new List<Product2>{prod,prod2};
        
        PriceBookEntry pbe = new PriceBookEntry(Pricebook2Id = pricebookId, CurrencyIsoCode = 'USD', Product2Id = prod.Id, IsActive = true, UnitPrice = 200.00, Purchase_Price__c = 100.00);
        insert pbe;
            
        Opportunity o = new Opportunity(Name = 'Opp 1', CurrencyIsoCode = 'USD', CloseDate = System.today(), Actual_Close_Date__c = System.today(), StageName = 'Qualified', AccountId = a.Id);
        insert o;
        
        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe.Id, UnitPrice = 200.00, Quantity = 1);
        insert oli;
        
        Quote q = new Quote(Name = 'Test Quote', CurrencyIsoCode = 'USD', Pricebook2Id = pricebookId,  OpportunityId = o.Id, Status = 'Draft'  );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(QuoteId = q.Id, Product2Id = prod.Id, PricebookEntryId = pbe.Id, UnitPrice = 200.00, Quantity = 1);
        qli.Product_Category__c = prod.Corresponding_Product_Category__c;
        
        QuoteLineItem qli2 = new QuoteLineItem(QuoteId = q.Id, Product2Id = prod.Id, PricebookEntryId = pbe.Id, UnitPrice = 200.00, Quantity = 1, opportunityLineItemId = oli.Id , Is_Created_By_Flow__c = true );
        qli.Product_Category__c = prod.Corresponding_Product_Category__c;
        
        insert new List<QuoteLineItem>{qli,qli2};

        List<QuoteLineItem> qliList = new List<QuoteLineItem>();
        qliList.add(qli);
        qliList.add(qli2);

        Set<Id> productSet = new Set<Id>();
        productSet.add(qli.Product2Id);
        
        o.SyncedQuoteId = q.Id;
        update o;
        
        qli.UnitPrice = 190;
        update qli;

        //QuoteLineItem_Trigger.setDefaultsfromProduct(qliList, productSet);
    }
}