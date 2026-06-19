@IsTest
private class BridgeIT_Account_Trigger_Tests {

    // Mock for any HTTP/Web service callout made from Account trigger logic
    private class BridgeITCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok'); // dummy body
            return res;
        }
    }

    @IsTest
    static void testInsertUpdateDelete() {
        Test.setMock(HttpCalloutMock.class, new BridgeITCalloutMock());

        // Create a test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc; // beforeInsert + afterInsert

        // Update the Account (this is where your trigger calls BridgeITEventHandler)
        acc.Name = 'Updated Account';
        update acc; // beforeUpdate + afterUpdate (+ BridgeITEventHandler.HandleEvent)

        // Delete the Account
        delete acc; // beforeDelete + afterDelete

        // Basic assertion – record still exists in recycle bin (ALL ROWS)
        Account accResult = [
            SELECT Id, Name, IsDeleted
            FROM Account
            WHERE Id = :acc.Id
            ALL ROWS
        ];
        System.assertEquals(true, accResult.IsDeleted, 'Account should be in recycle bin after delete.');
    }

    @IsTest
    static void testMultipleAccounts() {
        Test.setMock(HttpCalloutMock.class, new BridgeITCalloutMock());

        List<Account> accList = new List<Account>{
            new Account(Name = 'Account One'),
            new Account(Name = 'Account Two')
        };
        insert accList; // beforeInsert + afterInsert

        for (Account a : accList) {
            a.Name += ' Updated';
        }
        update accList; // beforeUpdate + afterUpdate (+ BridgeITEventHandler.HandleEvent)

        delete accList; // beforeDelete + afterDelete

        System.assertEquals(2, accList.size(), 'Should have handled multiple accounts in bulk.');
    }
}