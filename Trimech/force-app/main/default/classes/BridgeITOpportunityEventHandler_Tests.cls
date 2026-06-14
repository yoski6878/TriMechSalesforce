@IsTest
private class BridgeITOpportunityEventHandler_Tests {

    private static Integer callouts = 0;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITOpportunityEventHandler_Tests.callouts++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private static Opportunity createOpp(Boolean qualifyingStage) {
        Id standardPriceBookId = Test.getStandardPricebookId();
        Pricebook2 standardPriceBook = new Pricebook2(Id = standardPriceBookId, IsActive = true);
        update standardPriceBook;

    // Product
        Product2 p = new Product2(Name = 'Test Product', IsActive = true);
        insert p;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPriceBookId,
            Product2Id   = p.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        // Account + Contact
        Account a = new Account(Name = 'Test Account');
        insert a;

        Contact c = new Contact(FirstName = 'Test', LastName = 'Example', Email = 'alice@example.com', AccountId = a.Id);
        insert c;

        // Opportunity
        Opportunity o = new Opportunity(
            Name           = 'Test Opp',
            AccountId      = a.Id,
            StageName      = qualifyingStage ? 'Send to Order Management' : 'Prospecting',
            CloseDate      = System.today().addDays(30),
            Pricebook2Id   = standardPriceBookId,
            Primary_Contact__c = c.Id
        );
        insert o;

        // Opp Line Item
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId  = o.Id,
            PricebookEntryId = pbe.Id,
            Quantity       = 1,
            UnitPrice      = 100
        );
        insert oli;

        return o;
    }
    
    @IsTest
    static void test_qualifyingStage_callsOut() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Opportunity o = createOpp(true);

        Test.startTest();
        // The handler only uses the NEW list; OLD list isn’t referenced
        BridgeITOpportunityEventHandler.HandleOpportunityUpsert(
            new List<Opportunity>{ o }, null, 'create'
        );
        Test.stopTest();

        System.assertEquals(1, callouts, 'Expected one callout when StageName is "Send to Order Management".');
    }

    @IsTest
    static void test_nonQualifyingStage_skipsCallout() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Opportunity o = createOpp(false); // Stage != 'Send to Order Management'

        Test.startTest();
        BridgeITOpportunityEventHandler.HandleOpportunityUpsert(
            new List<Opportunity>{ o }, null, 'edit'
        );
        Test.stopTest();

        System.assertEquals(0, callouts, 'Expected no callout when StageName is not "Send to Order Management".');
    }
}