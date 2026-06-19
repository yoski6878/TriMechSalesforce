@IsTest
private class BridgeITOrderEventHandler_Tests {

    private static Integer callouts = 0;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITOrderEventHandler_Tests.callouts++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
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
        BridgeITOrderEventHandler.HandleOrderUpsert(
            new List<Order>{ o }, null, 'create'
        );
        Test.stopTest();

        System.assertEquals(1, callouts, 'Expected one callout when HandleOrderUpsert is invoked.');
    }
}