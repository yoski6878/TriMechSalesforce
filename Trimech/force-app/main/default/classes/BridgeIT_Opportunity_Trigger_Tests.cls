@IsTest
private class BridgeIT_Opportunity_Trigger_Tests {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void testInsertAndUpdate() {
        // Set mock to safely allow any callouts
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());

        // Create a parent Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Insert Opportunity 
        Opportunity opp = new Opportunity(
            Name      = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        // Update Opportunity
        opp.StageName = 'Qualification';
        update opp;

        // Basic assertion
        Opportunity result = [
            SELECT Id, StageName
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals('Qualification', result.StageName,
            'StageName should have been updated.');
    }

    @IsTest
    static void testBulkInsertAndUpdate() {
        // Set mock again for safety
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());

        Account acc = new Account(Name = 'Bulk Test Account');
        insert acc;

        // Bulk Insert Opportunities
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            opps.add(new Opportunity(
                Name      = 'Bulk Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                AccountId = acc.Id
            ));
        }
        insert opps; 

        // Bulk Update Opportunities
        for (Opportunity o : opps) {
            o.StageName = 'Qualification';
        }
        update opps; 

        System.assertEquals(3, opps.size(),
            'All opportunities should have been processed in bulk.');
    }
}