@IsTest
private class BridgeITContactEventHandler_Tests {

    private static Integer callouts = 0;

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BridgeITContactEventHandler_Tests.callouts++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void testCreate() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
    
        // Create Account with a NetSuite Id
        Account a = new Account(
            Name = 'Test Account',
            celigo_sfnsio__NetSuite_Id__c = '12345'
        );
        insert a;
    
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Example',
            Email = 'test@example.com',
            AccountId = a.Id
        );
    
        Test.startTest();
        BridgeITContactEventHandler.HandleContactUpsert(
            new List<Contact>{ c }, null, 'create'
        );
        Test.stopTest();
    
        System.assertEquals(1, callouts, 'Expected one callout for create.');
    }
    
    @IsTest
    static void testEdit() {
        callouts = 0;
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
    
        Account a = new Account(
            Name = 'Test Account',
            celigo_sfnsio__NetSuite_Id__c = '12345'
        );
        insert a;
    
        Contact oldC = new Contact(
            FirstName = 'Test',
            LastName = 'Example',
            Email = 'test@example.com',
            AccountId = a.Id
        );
        insert oldC;
        Contact newC = oldC.clone(true, true, false, false);
        newC.Email = 'test.new@example.com';
    
        Test.startTest();
        BridgeITContactEventHandler.HandleContactUpsert(
            new List<Contact>{ newC }, new List<Contact>{ oldC }, 'edit'
        );
        Test.stopTest();
    
        System.assertEquals(1, callouts, 'Expected one callout for edit.');
    }
}