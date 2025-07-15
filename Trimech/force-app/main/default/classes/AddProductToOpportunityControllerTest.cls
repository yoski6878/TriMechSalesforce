@isTest
public  class AddProductToOpportunityControllerTest {

    @isTest
    static void setupData(){

        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        // Pricebook2 customPB = new Pricebook2();
        // String passbookId = Test.getStandardPricebookId();
        // customPB.Id = passbookId;
        //insert customPB;

        Product2 p = new Product2(Name = 'Test Product', ProductCode='PC-00001231',  License_Type__c = 'ALC',
        Client_Type__c = 'Commercial',
        Network_Stand_Alone__c = 'Network',
        Elite_Essential__c = 'Elite',
        Class__c = '1 Solidworks',
        IsActive = true, CurrencyIsoCode = 'USD', Description = 'This is a test product.');

        Product2 p2 = new Product2(Name = 'Test Product', ProductCode='PC-0012312',  License_Type__c = 'ALC',
        Client_Type__c = 'Commercial',
        Network_Stand_Alone__c = 'Network',
        Elite_Essential__c = 'Elite',
        Class__c = '1 Solidworks', IsActive = true, CurrencyIsoCode = 'USD', Description = 'This is a test product.');
        insert new Product2[]{p,p2};

        Id standardPricebookId = Test.getStandardPricebookId();
        
        Product_Group__c g1 = new Product_Group__c(Name = 'Software', Default_Price_Book__c = String.valueOf(standardPricebookId));
        Product_Group__c g2 = new Product_Group__c(Name = 'Hardware', Default_Price_Book__c = String.valueOf(standardPricebookId));
        insert new Product_Group__c[]{g1,g2};
            
        Opportunity o1 = new Opportunity(Name = 'Opp 1', Product_Group__c = g1.Id, Pricebook2Id = standardPricebookId,  CloseDate = System.today(), StageName = 'Qualified', AccountId = a.Id, currencyISOCode = 'USD');
        insert o1;

    
        pricebookEntry pbe = new pricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = p.Id, UnitPrice = 100.00, IsActive = true, 
         CurrencyIsoCode = 'USD'  );
        pricebookEntry pbe2 = new pricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = p2.Id, UnitPrice = 100.00, IsActive = true , 
        CurrencyIsoCode = 'USD' );
        insert new pricebookEntry[]{pbe,pbe2};

        AddProductToOpportunityController.filterWrapper wrap = new AddProductToOpportunityController.filterWrapper();
        wrap.searchValue = 'Test';
        wrap.productCode = 'PC-00001231';
        wrap.licenseType = new List<String>{'ALC', 'Hardware'};
        wrap.clientType = new List<String>{'Commercial', 'Hardware'};
        wrap.network = new List<String>{'Network', 'Hardware'};
        wrap.eliteEssential = new List<String>{'Elite', 'Hardware'};
        wrap.productClass = new List<String>{'1 Solidworks', 'Hardware'};
        wrap.productType = 'Parent';

        AddProductToOpportunityController.filterWrapper wrap2 = new AddProductToOpportunityController.filterWrapper();
        wrap2.productType = 'All';
        
        Parent_Child_Product_Junction__c pcj = new Parent_Child_Product_Junction__c(Parent_Product__c = p.Id, Child_Product__c = p2.Id );
        insert pcj;
        Test.startTest();
            AddProductToOpportunityController.getProductData(o1.Id,'', true, wrap);
            AddProductToOpportunityController.getProductData(o1.Id,'', true, wrap2);
            List<Id> productIds = new List<Id>();
            productIds.add(p.Id);
            productIds.add(p2.Id);
            AddProductToOpportunityController.getRelatedChildProductData( productIds ,o1.Id);
        Test.stopTest();
        
        
    }
    
}