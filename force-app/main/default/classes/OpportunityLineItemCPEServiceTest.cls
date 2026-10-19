@IsTest
private class OpportunityLineItemCPEServiceTest {

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private static PricebookEntry createEntry(String name, String oem, String businessUnit) {
        Product2 p = new Product2(Name = name, IsActive = true, OEM__c = oem, Business_Unit__c = businessUnit);
        insert p;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = p.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;
        return pbe;
    }

    private static Opportunity createOpp(String stage) {
        update new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        Account a = new Account(Name = 'Test Account');
        insert a;
        Contact c = new Contact(FirstName = 'Test', LastName = 'Example', Email = 'alice@example.com', AccountId = a.Id);
        insert c;
        Opportunity o = new Opportunity(
            Name               = 'Test Opp',
            AccountId          = a.Id,
            StageName          = stage,
            CloseDate          = System.today().addDays(30),
            Pricebook2Id       = Test.getStandardPricebookId(),
            Primary_Contact__c = c.Id
        );
        insert o;
        return o;
    }

    private static OpportunityLineItem createLine(Id oppId, PricebookEntry pbe) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = oppId,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 100
        );
        insert oli;
        return oli;
    }

    private static String cpeOrder(Id oppId) {
        return [SELECT CPE_Order__c FROM Opportunity WHERE Id = :oppId].CPE_Order__c;
    }

    @IsTest
    static void addingDassaultEnterpriseProductSetsYes() {
        Opportunity o = createOpp('Prospecting');
        PricebookEntry cpe = createEntry('CPE Product', 'Dassault', 'Enterprise Solutions');

        Test.startTest();
        createLine(o.Id, cpe);
        Test.stopTest();

        System.assertEquals('Yes', cpeOrder(o.Id));
    }

    @IsTest
    static void otherProductsDoNotSetYes() {
        Opportunity o = createOpp('Prospecting');
        PricebookEntry dassaultApp = createEntry('Dassault App Product', 'Dassault', 'Application Solutions');
        PricebookEntry otherEnterprise = createEntry('TriMech Enterprise Product', 'TriMech', 'Enterprise Solutions');

        Test.startTest();
        createLine(o.Id, dassaultApp);
        createLine(o.Id, otherEnterprise);
        Test.stopTest();

        System.assertNotEquals('Yes', cpeOrder(o.Id));
    }

    @IsTest
    static void removingTheLastCpeProductSetsNo() {
        Opportunity o = createOpp('Prospecting');
        PricebookEntry cpe = createEntry('CPE Product', 'Dassault', 'Enterprise Solutions');
        OpportunityLineItem line = createLine(o.Id, cpe);
        System.assertEquals('Yes', cpeOrder(o.Id));

        Test.startTest();
        delete line;
        Test.stopTest();

        System.assertEquals('No', cpeOrder(o.Id));
    }

    @IsTest
    static void staysYesWhileAnotherCpeProductRemains() {
        Opportunity o = createOpp('Prospecting');
        PricebookEntry cpe = createEntry('CPE Product', 'Dassault', 'Enterprise Solutions');
        OpportunityLineItem first = createLine(o.Id, cpe);
        createLine(o.Id, cpe);

        Test.startTest();
        delete first;
        Test.stopTest();

        System.assertEquals('Yes', cpeOrder(o.Id));
    }

    @IsTest
    static void opportunityWaitingForNetSuiteIdIsLeftAlone() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Opportunity o = createOpp('Send to Order Management');
        PricebookEntry cpe = createEntry('CPE Product', 'Dassault', 'Enterprise Solutions');

        Test.startTest();
        createLine(o.Id, cpe);
        Test.stopTest();

        System.assertNotEquals('Yes', cpeOrder(o.Id));
    }
}
