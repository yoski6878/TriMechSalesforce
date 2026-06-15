@isTest
private class CreateLeadFromContactControllerTest {
    @testSetup
    static void setup() {
        Account a = new Account(Name = 'Acme Test');
        insert a;
        insert new Contact(FirstName = 'Pat', LastName = 'Tester', AccountId = a.Id);
    }

    @isTest
    static void getInitData_returnsAccountDefaults() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        CreateLeadFromContactController.InitData data = CreateLeadFromContactController.getInitData(c.Id);
        Test.stopTest();

        System.assertEquals(true, data.hasAccount, 'Contact should have an account');
        System.assertEquals('Acme Test - New Lead', data.defaultOppName, 'Default name should follow flow convention');
        System.assertNotEquals(null, data.leadRecordTypeId, 'Lead record type should resolve');
    }

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
    static void addTeamAndContactRole_insertsRoleAndTeam() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Opportunity opp = createOpportunity(c.AccountId, 'Acme Test - New Lead');

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

    @isTest
    static void addTeamAndContactRole_skipsDuplicateUsers() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Opportunity opp = createOpportunity(c.AccountId, 'Dup Test');

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

        // Only one row for the selected user, regardless of any owner the org auto-adds to the team.
        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityTeamMember WHERE OpportunityId = :opp.Id AND UserId = :teamUser.Id]
        );
    }

    private static Opportunity createOpportunity(Id accountId, String name) {
        User owner = createTestOwner();
        Opportunity opp;
        System.runAs(owner) {
            opp = new Opportunity(
                Name = name,
                AccountId = accountId,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            insert opp;
        }
        return opp;
    }

    private static User createTestOwner() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueName = String.valueOf(System.now().getTime());
        User u = new User(
            Alias = 'clfcown',
            Email = 'clfc.owner.' + uniqueName + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CLFC Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'clfc.owner.' + uniqueName + '@example.com'
        );
        insert u;
        return u;
    }
}
