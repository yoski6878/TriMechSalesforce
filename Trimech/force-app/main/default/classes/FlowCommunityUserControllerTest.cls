@IsTest
public class FlowCommunityUserControllerTest {

    @TestSetup
    static void setupData() {

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@test.com',
            Phone = '1234567890',
            AccountId = acc.Id
        );
        insert con;
    }

    @IsTest
    static void testGetPicklists() {
        Test.startTest();
        Map<String, List<FlowCommunityUserController.PicklistOption>> result =
            FlowCommunityUserController.getPicklists();
        Test.stopTest();
    }

    @IsTest
    static void testGetUserDetails_User() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            CommunityNickname = 'testnick',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        insert u;

        Test.startTest();
        Map<String, String> result =
            FlowCommunityUserController.getUserDetails(null, u.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetUserDetails_Contact() {

        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Map<String, String> result =
            FlowCommunityUserController.getUserDetails(con.Id, null);
        Test.stopTest();
    }

    @IsTest
    static void testUpsertUser_Insert() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'TriMech Customer Portal Manager Profile' LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Map<String, Object> userMap = new Map<String, Object>{
            'FirstName' => 'Flow',
            'LastName' => 'User',
            'Email' => 'flowuser@test.com',
            'Username' => 'flowuser' + System.currentTimeMillis() + '@test.com',
            'Alias' => 'fuser',
            'CommunityNickname' => 'flowNick',
            'TimeZoneSidKey' => 'Asia/Kolkata',
            'LocaleSidKey' => 'en_IN',
            'EmailEncodingKey' => 'UTF-8',
            'LanguageLocaleKey' => 'en_US',
            'ProfileId' => p.Id,
            'ContactId' => con.Id,
            'IsActive' => true
        };

        String userJson = JSON.serialize(userMap);

        Test.startTest();
        String userId = FlowCommunityUserController.upsertUser(userJson);
        Test.stopTest();
    }
}