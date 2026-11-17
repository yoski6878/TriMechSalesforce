@IsTest
private class OpportunityTeamMemberAccessTest {
    @TestSetup
    static void createTeamUser() {
        insert new User(
            Alias = 'opteam',
            Email = 'opteam@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Opportunity Team User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/New_York',
            Username = 'opteam.' + System.currentTimeMillis() + '@example.com'
        );
    }

    @IsTest
    static void supportedRoleReceivesEditAccess() {
        Opportunity opportunity = new Opportunity(
            Name = 'Opportunity Team Access Test',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;
        User teamUser = [SELECT Id FROM User WHERE Alias = 'opteam' LIMIT 1];

        OpportunityTeamMember member = new OpportunityTeamMember(
            OpportunityId = opportunity.Id,
            UserId = teamUser.Id,
            TeamMemberRole = 'Sales Rep',
            OpportunityAccessLevel = 'Read'
        );
        insert member;

        member = [
            SELECT OpportunityAccessLevel
            FROM OpportunityTeamMember
            WHERE Id = :member.Id
        ];
        System.assertEquals('Edit', member.OpportunityAccessLevel);
    }
}
