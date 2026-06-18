@IsTest
private class BridgeIT_Contact_Trigger_Tests {

    // Mock for any HTTP call BridgeITEventHandler makes
    private class BridgeITCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok'); // whatever dummy body you want
            return res;
        }
    }

    @IsTest
    static void testInsertAndUpdate() {
        Test.setMock(HttpCalloutMock.class, new BridgeITCalloutMock());

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName  = 'User',
            Email     = 'test.user@example.com',
            AccountId = acc.Id
        );
        insert c;   // Contact_Trigger -> BridgeITEventHandler.HandleEvent -> callout (mocked)

        c.Email = 'updated.user@example.com';
        update c;   // Contact_Trigger -> BridgeITEventHandler.HandleEvent -> callout (mocked)

        Contact result = [SELECT Id, Email FROM Contact WHERE Id = :c.Id];
        System.assertEquals('updated.user@example.com', result.Email);
    }
}