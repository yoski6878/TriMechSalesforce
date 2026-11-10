/**
* @File Name : NukeDeactivationServiceTest.cls
* @Description : Tests for the Contact NUKE rules in NukeDeactivationService. Uses synthetic test data only.
**/

@isTest
private class NukeDeactivationServiceTest {

    @testSetup
    static void setupTestData() {
        insert new Account(Name = 'ZZZ_TEST_Nuke_Service_Parent');
    }

    private static Account parentAccount() {
        return [SELECT Id FROM Account WHERE Name = 'ZZZ_TEST_Nuke_Service_Parent' LIMIT 1];
    }

    private static Contact newContact(String lastName) {
        Contact record = new Contact(LastName = lastName, AccountId = parentAccount().Id, NUKE__c = true);
        insert record;
        return record;
    }

    private static Opportunity newOpportunity(Map<String, Object> values) {
        Opportunity opp = new Opportunity(
            Name = 'ZZZ_TEST_Nuke_Opp',
            StageName = 'In Progress',
            CloseDate = Date.today().addDays(30),
            AccountId = parentAccount().Id
        );
        for (String field : values.keySet()) {
            opp.put(field, values.get(field));
        }
        insert opp;
        return opp;
    }

    @isTest
    static void contactWithNoActivityIsDeletedAndRemovedFromRelatedRecords() {
        Contact gone = newContact('ZZZ_TEST_Nuke_Gone');
        Contact kept = newContact('ZZZ_TEST_Nuke_Kept');
        Asset asset = new Asset(Name = 'ZZZ_TEST_Nuke_Asset', AccountId = parentAccount().Id, ContactId = gone.Id);
        insert asset;
        Opportunity opp = newOpportunity(new Map<String, Object>{
            'Primary_Contact__c' => gone.Id,
            'End_User_Ids__c' => '[' + gone.Id + ',' + kept.Id + ']',
            'End_User_Names__c' => '[Gone Person,Kept Person]',
            'End_User_Netsuite_Ids__c' => '[111,222]'
        });

        Test.startTest();
        NukeDeactivationService.RunResult result = NukeDeactivationService.processContacts(new Set<Id>{ gone.Id });
        Test.stopTest();

        NukeDeactivationService.ContactResult contactResult = result.contacts[0];
        System.assertEquals(NukeDeactivationService.ACTION_DELETED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_NO_ACTIVITY, contactResult.reason);
        System.assert(contactResult.isSuccess(), contactResult.error);
        System.assertEquals(1, contactResult.assetsCleared);
        System.assertEquals(1, contactResult.opportunitiesUpdated);
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE Id = :gone.Id], 'Contact should be deleted.');
        System.assertEquals(1, result.clearedAssets.size());

        Asset assetAfter = [SELECT ContactId, Inactive__c FROM Asset WHERE Id = :asset.Id];
        System.assertEquals(null, assetAfter.ContactId, 'Asset should be kept with the Contact cleared.');
        System.assertEquals(false, assetAfter.Inactive__c, 'Asset should stay active.');

        Opportunity oppAfter = [SELECT Primary_Contact__c, NUKE_Deactivated__c, End_User_Ids__c, End_User_Names__c, End_User_Netsuite_Ids__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, oppAfter.Primary_Contact__c);
        System.assertEquals(false, oppAfter.NUKE_Deactivated__c, 'Opportunity should stay active.');
        System.assertEquals('[' + kept.Id + ']', oppAfter.End_User_Ids__c);
        System.assertEquals('[Kept Person]', oppAfter.End_User_Names__c);
        System.assertEquals('[222]', oppAfter.End_User_Netsuite_Ids__c);
    }

    @isTest
    static void contactWithRecentActivityIsInactivatedAndRelatedRecordsStayActive() {
        Contact record = newContact('ZZZ_TEST_Nuke_Active');
        insert new Task(WhoId = record.Id, Subject = 'ZZZ_TEST_Nuke_Call', Status = 'Completed', ActivityDate = Date.today().addDays(-5));
        Opportunity opp = newOpportunity(new Map<String, Object>{ 'Primary_Contact__c' => record.Id });
        Case relatedCase = new Case(Subject = 'ZZZ_TEST_Nuke_Case', ContactId = record.Id, AccountId = parentAccount().Id);
        insert relatedCase;

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_RECENT_ACTIVITY, contactResult.reason);
        Contact after = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id = :record.Id];
        System.assert(after.Inactive__c && !after.NUKE__c);

        Opportunity oppAfter = [SELECT Primary_Contact__c, NUKE_Deactivated__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(record.Id, oppAfter.Primary_Contact__c, 'Inactivated Contact stays linked.');
        System.assertEquals(false, oppAfter.NUKE_Deactivated__c);
        System.assertEquals(false, [SELECT NUKE_Deactivated__c FROM Case WHERE Id = :relatedCase.Id].NUKE_Deactivated__c);
    }

    @isTest
    static void contactOnRecentOrderIsInactivated() {
        Contact record = newContact('ZZZ_TEST_Nuke_Order');
        insert new Order(AccountId = parentAccount().Id, Status = 'Draft', EffectiveDate = Date.today().addYears(-2), BillToContactId = record.Id);

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_RECENT_ORDER, contactResult.reason);
        System.assertEquals(1, [SELECT COUNT() FROM Contact WHERE Id = :record.Id]);
    }

    @isTest
    // Salesforce blocks deleting a Contact on the standard Order contact fields, so an old Order is still a hold.
    static void contactOnOldOrderIsInactivatedBecauseDeleteIsBlocked() {
        Contact record = newContact('ZZZ_TEST_Nuke_Old_Order');
        Asset asset = new Asset(Name = 'ZZZ_TEST_Nuke_Asset', AccountId = parentAccount().Id, ContactId = record.Id);
        insert asset;
        insert new Order(AccountId = parentAccount().Id, Status = 'Draft', EffectiveDate = Date.today().addYears(-9), BillToContactId = record.Id);

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_ORDER_BLOCKS_DELETE, contactResult.reason);
        System.assert(contactResult.isSuccess(), contactResult.error);
        Contact after = [SELECT Inactive__c, NUKE__c FROM Contact WHERE Id = :record.Id];
        System.assert(after.Inactive__c && !after.NUKE__c);
        System.assertEquals(record.Id, [SELECT ContactId FROM Asset WHERE Id = :asset.Id].ContactId, 'Inactivated Contact stays on its Asset.');
    }

    @isTest
    static void contactOnlyOnOldOrderCustomContactFieldIsDeleted() {
        Contact record = newContact('ZZZ_TEST_Nuke_Old_Order_Custom');
        Order oldOrder = new Order(AccountId = parentAccount().Id, Status = 'Draft', EffectiveDate = Date.today().addYears(-9), Order_Contact__c = record.Id);
        insert oldOrder;

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_DELETED, contactResult.action, contactResult.reason);
        System.assertEquals(null, [SELECT Order_Contact__c FROM Order WHERE Id = :oldOrder.Id].Order_Contact__c, 'Order is kept with the Contact cleared.');
    }

    @isTest
    static void contactOnAdobeSignAgreementIsInactivated() {
        Contact record = newContact('ZZZ_TEST_Nuke_Signer');
        insert new echosign_dev1__SIGN_Agreement__c(Name = 'ZZZ_TEST_Nuke_Agreement', echosign_dev1__Recipient__c = record.Id);

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_ADOBE_SIGN, contactResult.reason);
    }

    @isTest
    static void mismatchedOrderManagementListInactivatesInsteadOfDeleting() {
        Contact record = newContact('ZZZ_TEST_Nuke_Mismatch');
        Opportunity opp = newOpportunity(new Map<String, Object>{
            'Student_Ids__c' => '[' + record.Id + ']',
            'Student_Names__c' => '[Last, First]',
            'Student_Netsuite_Ids__c' => '[333]'
        });

        Test.startTest();
        NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.processContacts(new Set<Id>{ record.Id }).contacts[0];
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, contactResult.action);
        System.assertEquals(NukeDeactivationService.REASON_LIST_MISMATCH, contactResult.reason);
        System.assertEquals(1, [SELECT COUNT() FROM Contact WHERE Id = :record.Id]);
        System.assertEquals('[' + record.Id + ']', [SELECT Student_Ids__c FROM Opportunity WHERE Id = :opp.Id].Student_Ids__c, 'Opportunity should be unchanged.');
    }

    @isTest
    static void previewShowsDeleteOrInactivate() {
        Contact toDelete = newContact('ZZZ_TEST_Nuke_Preview_Delete');
        Contact toKeep = newContact('ZZZ_TEST_Nuke_Preview_Keep');
        insert new Task(WhoId = toKeep.Id, Subject = 'ZZZ_TEST_Nuke_Call', Status = 'Completed', ActivityDate = Date.today().addDays(-1));
        insert new Asset(Name = 'ZZZ_TEST_Nuke_Asset', AccountId = parentAccount().Id, ContactId = toDelete.Id);

        Test.startTest();
        NukeDeactivationService.ContactPreview deletePreview = NukeDeactivationService.previewContact(toDelete.Id);
        NukeDeactivationService.ContactPreview keepPreview = NukeDeactivationService.previewContact(toKeep.Id);
        Test.stopTest();

        System.assertEquals(NukeDeactivationService.ACTION_DELETED, deletePreview.action);
        System.assertEquals(1, deletePreview.assets);
        System.assert(deletePreview.summary().contains('will be DELETED'));
        System.assertEquals(NukeDeactivationService.ACTION_INACTIVATED, keepPreview.action);
        System.assert(keepPreview.summary().contains('will NOT be deleted'));
        System.assertEquals(2, [SELECT COUNT() FROM Contact WHERE Id IN :new List<Id>{ toDelete.Id, toKeep.Id }], 'Preview should not change anything.');
    }

    @isTest
    static void parseAndFormatLists() {
        System.assertEquals(0, NukeDeactivationService.parseList(null).size());
        System.assertEquals(0, NukeDeactivationService.parseList('[]').size());
        System.assertEquals(new List<String>{ 'a', 'b' }, NukeDeactivationService.parseList('[a, b]'));
        System.assertEquals(new List<String>{ 'a', '' }, NukeDeactivationService.parseList('[a,]'));
        System.assertEquals(null, NukeDeactivationService.formatList(new List<String>()));
        System.assertEquals('[a,b]', NukeDeactivationService.formatList(new List<String>{ 'a', 'b' }));
    }

    @isTest
    static void invalidRecordIdIsRejected() {
        try {
            NukeDeactivationService.runContact(parentAccount().Id);
            System.assert(false, 'Expected an exception for a non-Contact Id.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Contact'));
        }
    }
}
