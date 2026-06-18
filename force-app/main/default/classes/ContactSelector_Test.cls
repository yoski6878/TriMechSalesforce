@isTest
private class ContactSelector_Test {

    // ── helpers ────────────────────────────────────────────────────────────────

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity o = new Opportunity(
            Name       = 'Test Opp',
            AccountId  = accountId,
            StageName  = 'Prospecting',
            CloseDate  = Date.today().addDays(30)
        );
        insert o;
        return o;
    }

    private static Contact makeContact(String lastName, String email, Id accountId, Boolean inactive) {
        Contact c = new Contact(
            LastName     = lastName,
            Email        = email,
            AccountId    = accountId,
            Inactive__c  = inactive
        );
        insert c;
        return c;
    }

    // ── getAccountIdFromOpportunity ────────────────────────────────────────────

    @isTest
    static void testGetAccountIdFromOpportunity_Happy() {
        Account acct = makeAccount('Selector Test Acct');
        Opportunity opp = makeOpportunity(acct.Id);

        Test.startTest();
        Id result = ContactSelector.getAccountIdFromOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals(acct.Id, result, 'Should return the Account Id from the Opportunity');
    }

    @isTest
    static void testGetAccountIdFromOpportunity_NullThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ContactSelector.getAccountIdFromOpportunity(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Null opportunityId should throw AuraHandledException');
    }

    // ── getContactById ─────────────────────────────────────────────────────────

    @isTest
    static void testGetContactById_Found() {
        Account acct = makeAccount('Selector Acct CB');
        Contact c = makeContact('Smith', 'smith@example.com', acct.Id, false);

        Test.startTest();
        ContactSelector.ContactLookupResult result = ContactSelector.getContactById(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a result for a valid Contact Id');
        System.assertEquals(c.Id, result.contactId, 'contactId should match');
        System.assertEquals('Smith', result.name, 'name should match');
        System.assertEquals('smith@example.com', result.email, 'email should match');
    }

    @isTest
    static void testGetContactById_NullReturnsNull() {
        Test.startTest();
        ContactSelector.ContactLookupResult result = ContactSelector.getContactById(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Null contactId should return null');
    }

    // ── getContactsByIds ───────────────────────────────────────────────────────

    @isTest
    static void testGetContactsByIds_EmptyListReturnsEmpty() {
        Test.startTest();
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.getContactsByIds(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should return empty list');
    }

    @isTest
    static void testGetContactsByIds_MultipleFound() {
        Account acct = makeAccount('Selector Acct CIs');
        Contact c1 = makeContact('Alpha', 'alpha@example.com', acct.Id, false);
        Contact c2 = makeContact('Beta',  'beta@example.com',  acct.Id, false);

        Test.startTest();
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.getContactsByIds(new List<Id>{ c1.Id, c2.Id });
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return both contacts');
    }

    // ── searchContacts ─────────────────────────────────────────────────────────

    @isTest
    static void testSearchContacts_NullAccountIdThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ContactSelector.searchContacts(null, '', 5);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Null accountId should throw AuraHandledException');
    }

    @isTest
    static void testSearchContacts_EmptyTerm_Returns5ByName() {
        Account acct = makeAccount('Selector Acct Search');
        String[] names = new String[]{ 'Ava', 'Ben', 'Cal', 'Dan', 'Eve', 'Fay', 'Gil' };
        for (String n : names) {
            makeContact(n, n.toLowerCase() + '@example.com', acct.Id, false);
        }

        Test.startTest();
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.searchContacts(acct.Id, '', 5);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Empty term with limitSize=5 should return exactly 5');
        System.assertEquals('Ava', results[0].name, 'First result should be alphabetically first');
        System.assertEquals('Eve', results[4].name, 'Fifth result should be Eve');
    }

    @isTest
    static void testSearchContacts_WithTerm_FiltersResults() {
        Account acct = makeAccount('Selector Acct Filter');
        makeContact('Thompson', 'thompson@example.com', acct.Id, false);
        makeContact('Torres',   'torres@example.com',   acct.Id, false);
        makeContact('Wilson',   'wilson@example.com',   acct.Id, false);

        Test.startTest();
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.searchContacts(acct.Id, 'Tho', 25);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Search for "Tho" should return only Thompson');
        System.assertEquals('Thompson', results[0].name, 'Returned contact should be Thompson');
    }

    @isTest
    static void testSearchContacts_InactiveContactsFiltered() {
        Account acct = makeAccount('Selector Acct Inactive');
        makeContact('ActiveOne',   'active@example.com',   acct.Id, false);
        makeContact('InactiveOne', 'inactive@example.com', acct.Id, true);

        Test.startTest();
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.searchContacts(acct.Id, '', 25);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Inactive contacts should be excluded');
        System.assertEquals('ActiveOne', results[0].name, 'Only the active contact should be returned');
    }

    @isTest
    static void testSearchContacts_LimitSizeClamped() {
        Account acct = makeAccount('Selector Acct Clamp');
        makeContact('Clamp', 'clamp@example.com', acct.Id, false);

        Test.startTest();
        // limitSize=0 is invalid — should clamp to 25 and still return the 1 available record
        List<ContactSelector.ContactLookupResult> results =
            ContactSelector.searchContacts(acct.Id, '', 0);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Invalid limitSize=0 should clamp and still return results');
    }
}