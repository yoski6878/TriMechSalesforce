@IsTest
private class BridgeITEventHandler_Tests {

    private static Integer callouts = 0;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITEventHandler_Tests.callouts++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
    
    @IsTest
    static void testHandleEvent_filterOutExecuteFirstSessionVerification() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Test.startTest();
        BridgeITEventHandler.skipSessionCheck = false;
        BridgeITEventHandler.HandleEvent(
            new List<SObject>{ acc },
            null,
            'account',
            'create'
        );
        Test.stopTest();

        System.assertEquals(0, callouts, 'Account event should have triggered zero callout.');
    }
    
    @IsTest
    static void testHandleEvent_filterOutExecuteSecondSessionVerification() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Test.startTest();
        BridgeITEventHandler.skipSessionCheck = false;
        BridgeITEventHandler.HandleEvent(
            new List<SObject>{ acc },
            null,
            'account',
            'create'
        );
        Test.stopTest();

        System.assertEquals(0, callouts, 'Account event should have triggered zero callout.');
    }
    @IsTest
    static void testHandleEvent_routesToAccount() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Send to Order Management',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id 
        );
        insert opp;
        
        Test.startTest();
        BridgeITEventHandler.skipSessionCheck = true;
        BridgeITEventHandler.HandleEvent(
            new List<SObject>{ acc },
            null,
            'account',
            'create'
        );
        BridgeITEventHandler.skipSessionCheck = false;
        Test.stopTest();

        System.assertEquals(1, callouts, 'Account event should have triggered one callout.');
    }

    @IsTest
static void testHandleEvent_routesToContact() {
    Test.setMock(HttpCalloutMock.class, new CalloutMock());

    // Arrange: Account with a NetSuite Id so the handler doesn't early-return
    Account a = new Account(
        Name = 'Test Account',
        celigo_sfnsio__NetSuite_Id__c = '12345'
    );
    insert a;
    
    // Contact linked to that Account
    Contact con = new Contact(
        FirstName = 'Test',
        LastName = 'Example',
        Email = 'test@example.com',
        AccountId = a.Id
    );
    Test.startTest();
    BridgeITEventHandler.skipSessionCheck = true;
    BridgeITEventHandler.HandleEvent(
        new List<SObject>{ con },
        null,
        'contact',
        'create'
    );
    BridgeITEventHandler.skipSessionCheck = false;
    Test.stopTest();

    System.assertEquals(2, callouts, 'Contact event should have triggered one callout.');
}
    
    @IsTest
    static void testOrderHandler_callsOut() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Order o = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today()
        );
        insert o;

        Test.startTest();
        BridgeITEventHandler.HandleEvent(
            new List<SObject>{ o }, null, 'order','create'
        );
        Test.stopTest();

        System.assertEquals(1, callouts, 'Expected one callout when HandleOrderUpsert is invoked.');
    }

    @IsTest
    static void testRunOnce() {
        System.assertEquals(true, BridgeITEventHandler.runOnce(),
            'First call to runOnce() should return true.');
        System.assertEquals(false, BridgeITEventHandler.runOnce(),
            'Second call to runOnce() should return false.');
    }
}