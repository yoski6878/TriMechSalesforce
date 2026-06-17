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
            opp.Id, c.Id, new List<CreateLeadFromContactController.TeamMemberInput>{ tm }
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
            opp.Id, null, new List<CreateLeadFromContactController.TeamMemberInput>{ tm1, tm2 }
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityTeamMember WHERE OpportunityId = :opp.Id AND UserId = :teamUser.Id]
        );
    }
}
