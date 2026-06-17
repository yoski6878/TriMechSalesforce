@isTest
private class CreateLeadFromContactControllerTest {
    @isTest
    static void getTeamRoleOptions_returnsActiveValues() {
        Test.startTest();
        List<Map<String, String>> options = CreateLeadFromContactController.getTeamRoleOptions();
        Test.stopTest();

        System.assertNotEquals(0, options.size(), 'TeamMemberRole should expose active picklist values');
        for (Map<String, String> opt : options) {
            System.assert(opt.containsKey('label') && opt.containsKey('value'), 'Each option needs label and value');
        }
    }

    @isTest
    static void getDefaultTeamMembers_returnsList() {
        Test.startTest();
        List<Map<String, String>> members = CreateLeadFromContactController.getDefaultTeamMembers();
        Test.stopTest();

        System.assertNotEquals(null, members, 'Should return a list (possibly empty)');
        for (Map<String, String> m : members) {
            System.assert(m.containsKey('name') && m.containsKey('role'), 'Each entry needs name and role');
        }
    }

    @isTest
    static void getInitData_fromContact_returnsAccountDefaults() {
        Account a = new Account(Name = 'Acme Test');
        insert a;
        Contact c = new Contact(FirstName = 'Pat', LastName = 'Tester', AccountId = a.Id);
        insert c;

        Test.startTest();
        CreateLeadFromContactController.InitData data = CreateLeadFromContactController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals(false, data.isAccount, 'Launched from a Contact');
        System.assertEquals(true, data.hasAccount, 'Contact should have an account');
        System.assertEquals('Acme Test - New Lead', data.defaultOppName, 'Default name should follow flow convention');
        System.assertNotEquals(null, data.leadRecordTypeId, 'Lead record type should resolve');
    }

    @isTest
    static void getInitData_fromAccount_returnsAccountDefaults() {
        Account a = new Account(Name = 'Acme Test');
        insert a;

        Test.startTest();
        CreateLeadFromContactController.InitData data = CreateLeadFromContactController.getInitData(a.Id);
        Test.stopTest();

        System.assertEquals(true, data.isAccount, 'Launched from an Account');
        System.assertEquals(a.Id, data.accountId, 'Account should be the record itself');
        System.assertEquals('Acme Test - New Lead', data.defaultOppName, 'Default name should follow flow convention');
    }

    // SeeAllData=true so the running user's Default Opportunity Team (UserTeamMember rows)
    // is visible. Without it, the platform can't auto-add the owner on Opportunity insert,
    // and the standard owner-split fails with INVALID_CROSS_REFERENCE_KEY — an org-wide
    // test-context issue, not a defect in this feature.
    @isTest(SeeAllData=true)
    static void addTeamAndContactRole_insertsRoleAndTeam() {
        String uniq = String.valueOf(System.now().getTime());
        Account a = new Account(Name = 'CLFC ' + uniq);
        insert a;
        Contact c = new Contact(FirstName = 'Pat', LastName = 'Tester' + uniq, AccountId = a.Id);
        insert c;
        Opportunity opp = new Opportunity(
            Name = 'CLFC Opp ' + uniq,
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        User teamUser = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard' AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        CreateLeadFromContactController.TeamMemberInput tm = new CreateLeadFromContactController.TeamMemberInput();
        tm.userId = teamUser.Id;
        tm.accessLevel = 'Read';

        Test.startTest();
        CreateLeadFromContactController.addTeamAndContactRole(
            opp.Id, c.Id, null, new List<CreateLeadFromContactController.TeamMemberInput>{ tm }
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :opp.Id AND IsPrimary = true]);
        System.assertEquals(1, [SELECT COUNT() FROM OpportunityTeamMember WHERE OpportunityId = :opp.Id AND UserId = :teamUser.Id]);
    }

    @isTest(SeeAllData=true)
    static void addTeamAndContactRole_skipsDuplicateUsers() {
        String uniq = String.valueOf(System.now().getTime()) + 'd';
        Account a = new Account(Name = 'CLFC ' + uniq);
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'CLFC Dup ' + uniq,
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        User teamUser = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard' AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        CreateLeadFromContactController.TeamMemberInput tm1 = new CreateLeadFromContactController.TeamMemberInput();
        tm1.userId = teamUser.Id;
        CreateLeadFromContactController.TeamMemberInput tm2 = new CreateLeadFromContactController.TeamMemberInput();
        tm2.userId = teamUser.Id;

        Test.startTest();
        CreateLeadFromContactController.addTeamAndContactRole(
            opp.Id, null, null, new List<CreateLeadFromContactController.TeamMemberInput>{ tm1, tm2 }
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityTeamMember WHERE OpportunityId = :opp.Id AND UserId = :teamUser.Id]
        );
    }

    @isTest
    static void getAccountContacts_returnsContactsOnAccount() {
        Account a = new Account(Name = 'Contacts Co');
        insert a;
        insert new Contact(FirstName = 'Ann', LastName = 'Example', AccountId = a.Id);

        Test.startTest();
        List<Map<String, String>> opts = CreateLeadFromContactController.getAccountContacts(a.Id);
        Test.stopTest();

        System.assertEquals(1, opts.size(), 'Should return the account contact');
        System.assert(opts[0].containsKey('label') && opts[0].containsKey('value'), 'Needs label/value');
        System.assertEquals(0, CreateLeadFromContactController.getAccountContacts(null).size(), 'Null account -> empty');
    }

    @isTest
    static void getOpportunityPicklist_returnsValues() {
        Test.startTest();
        List<Map<String, String>> typeOpts = CreateLeadFromContactController.getOpportunityPicklist('Type');
        List<Map<String, String>> bogus = CreateLeadFromContactController.getOpportunityPicklist('Not_A_Field__c');
        Test.stopTest();

        System.assertNotEquals(null, typeOpts, 'Should return Type picklist options');
        System.assertEquals(0, bogus.size(), 'Unknown field returns empty list');
    }

    @isTest
    static void getActiveCampaigns_returnsActiveInProgress() {
        insert new Campaign(Name = 'Active C', IsActive = true, Status = 'In Progress', EndDate = Date.today().addDays(10));

        Test.startTest();
        List<Map<String, String>> opts = CreateLeadFromContactController.getActiveCampaigns();
        Test.stopTest();

        System.assert(opts.size() >= 1, 'Should return the active in-progress campaign');
    }

    @isTest(SeeAllData=true)
    static void addTeamAndContactRole_createsNewContact() {
        String uniq = String.valueOf(System.now().getTime()) + 'n';
        Account a = new Account(Name = 'CLFC ' + uniq);
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'CLFC New ' + uniq,
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        CreateLeadFromContactController.NewContactInput nc = new CreateLeadFromContactController.NewContactInput();
        nc.firstName = 'Fresh';
        nc.lastName = 'Lead' + uniq;
        nc.email = 'fresh' + uniq + '@example.com';
        nc.phone = '555-0100';

        Test.startTest();
        CreateLeadFromContactController.addTeamAndContactRole(opp.Id, null, nc, null);
        Test.stopTest();

        Contact created = [SELECT Id, AccountId FROM Contact WHERE LastName = :nc.lastName LIMIT 1];
        System.assertEquals(a.Id, created.AccountId, 'New contact should be on the account');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityContactRole WHERE OpportunityId = :opp.Id AND ContactId = :created.Id AND IsPrimary = true]
        );
    }
}
