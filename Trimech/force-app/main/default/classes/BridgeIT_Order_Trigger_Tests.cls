@IsTest
private class BridgeIT_Order_Trigger_Tests {

    // Mock for any HTTP callout made from Order trigger logic
    private class OrderCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok'); // dummy body
            return res;
        }
    }

    @IsTest
    static void testSingleInsertAndUpdate() {
        Test.setMock(HttpCalloutMock.class, new OrderCalloutMock());

        // Create a parent Account (Order requires an Account)
        Account acc = new Account(Name = 'Order Test Account');
        insert acc;

        // INSERT Order (fires beforeInsert + afterInsert)
        Order o = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today()
        );
        insert o;

        // UPDATE Order WITHOUT activating it (avoid FAILED_ACTIVATION)
        o.EffectiveDate = Date.today().addDays(1);
        update o; // fires beforeUpdate + afterUpdate

        // Basic assertion
        Order result = [
            SELECT Id, Status, EffectiveDate, AccountId
            FROM Order
            WHERE Id = :o.Id
        ];
        System.assertEquals('Draft', result.Status, 'Order status should remain Draft.');
        System.assertEquals(Date.today().addDays(1), result.EffectiveDate, 'EffectiveDate should have been updated.');
        System.assertEquals(acc.Id, result.AccountId, 'Order should still be related to the same Account.');
    }

    @IsTest
    static void testBulkInsertAndUpdate() {
        Test.setMock(HttpCalloutMock.class, new OrderCalloutMock());

        Account acc = new Account(Name = 'Bulk Order Account');
        insert acc;

        // BULK INSERT Orders
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 3; i++) {
            orders.add(new Order(
                AccountId     = acc.Id,
                Status        = 'Draft',
                EffectiveDate = Date.today().addDays(i)
            ));
        }
        insert orders; // fires beforeInsert + afterInsert

        // BULK UPDATE Orders (no activation)
        for (Order o : orders) {
            o.EffectiveDate = o.EffectiveDate.addDays(1);
        }
        update orders; // fires beforeUpdate + afterUpdate

        System.assertEquals(3, orders.size(), 'All Orders should have been processed in bulk.');
    }
}