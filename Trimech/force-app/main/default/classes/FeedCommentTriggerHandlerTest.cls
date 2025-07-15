@isTest
public class FeedCommentTriggerHandlerTest {
    	
    static testMethod void testTrigger() {

        Test.StartTest();
		
        Profile triMechProfile = [SELECT Id FROM Profile WHERE Name = 'TriMech Customer Portal Profile' LIMIT 1];

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'contact@example.com',
            AccountId = acc.Id
        );
        insert con;

        User triMechUser = new User(
            FirstName = 'Test',
            LastName = 'PortalUser',
            Email = 'portaluser@example.com',
            Username = 'portaluser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = triMechProfile.Id,
            ContactId = con.Id
        );
        insert triMechUser;

        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User ownerUser = new User(
            FirstName = 'Admin',
            LastName = 'User',
            Email = 'adminuser@example.com',
            Username = 'adminuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'adminu',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id
        );
        insert ownerUser;


        //User ownerUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        // Create Case visible to portal user
        Case c = new Case(
            Subject = 'Case from test',
            Status = 'Waiting for Client',
            OwnerId = ownerUser.Id,
            Type = 'Printer Repair',
            ContactId = con.Id,   // associate contact
            Origin = 'Web'        // some portals need this
        );
        insert c;

        System.runAs(triMechUser) {
            FeedItem f = new FeedItem();
            f.ParentId = c.Id;
            f.Body = 'test';
            insert f;

            FeedComment fc = new FeedComment();
            fc.CommentBody = 'legal test';
            fc.FeedItemId = f.Id;
            insert fc;

            //FeedComment fcQ = [SELECT Id, CommentBody, FeedItemId, ParentId FROM FeedComment LIMIT 1];
        }

        Test.StopTest();
    }
}