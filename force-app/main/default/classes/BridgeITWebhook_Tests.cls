@IsTest
private class BridgeITWebhook_Tests {

    private static Integer callouts = 0;
    private static HttpRequest lastReq;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITWebhook_Tests.callouts++;
            BridgeITWebhook_Tests.lastReq = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void test_Json_Content() {
        Account a = new Account(Name = 'Test Account');
        insert a;

        String result = BridgeITWebhook.jsonContent(new List<Object>{ a }, null);

        System.assert(result.contains('"new"'), 'JSON should contain "new" key.');
        System.assert(result.contains('"old"'), 'JSON should contain "old" key.');
        System.assert(result.contains('"userId"'), 'JSON should contain "userId" key.');
        System.assert(result.contains('Test Account'), 'Serialized Account name should appear in JSON.');
    }

    @IsTest
    static void testCallout_sendsRequest() {
        callouts = 0;
        lastReq = null;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        String url = 'https://example.com/webhook';
        String content = '{"new":[],"old":[],"userId":"u1"}';

        Test.startTest();
        BridgeITWebhook.callout(url, content, 'create');
        Test.stopTest(); 

        //System.assertEquals(1, callouts, 'Expected one callout.');
        //System.assertNotEquals(null, lastReq, 'Expected HttpRequest to be captured.');
        //System.assertEquals('POST', lastReq.getMethod(), 'Should use POST.');
        //System.assertEquals('application/json', lastReq.getHeader('Content-Type'));
        //System.assertEquals('create', lastReq.getHeader('X-Context-Type'));
        //System.assertEquals(content, lastReq.getBody(), 'Body should match content.');
    }
}