@IsTest
private class BridgeITAccountEventHandler_Tests {

    private static Integer callouts = 0;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITAccountEventHandler_Tests.callouts++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void testCreate() {
        CalloutMock mock = new CalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Account a = new Account(Name = 'Test Account', celigo_sfnsio__Skip_Export_To_NetSuite__c = false);
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp',
            StageName = 'Send to Order Management',
            CloseDate = System.today().addDays(30),
            AccountId = a.Id 
        );
        insert opp;
        Test.startTest();
        callouts = 0;
        BridgeITAccountEventHandler.HandleAccountUpsert(
            new List<Account>{ a }, null, 'create'
        );
        Test.stopTest();

        System.assertEquals(1, callouts, 'Create should trigger one callout.');
    }

    @IsTest
    static void testEdit_skipTrue() {
        
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Account oldA = new Account(Name = 'Test Account', celigo_sfnsio__Skip_Export_To_NetSuite__c = true);
        insert oldA;
        Account newA = oldA.clone(true, true, false, false);
        callouts = 0;
        Test.startTest();
        update newA;
        BridgeITAccountEventHandler.HandleAccountUpsert(
            new List<Account>{ newA }, new List<Account>{ oldA }, 'edit'
        );
        Test.stopTest();

        System.assertEquals(0, callouts,
            'Edit with skip=true and no significant changes should not call out.');
    }

}