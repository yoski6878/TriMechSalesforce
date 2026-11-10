@IsTest
private class CommissionableGPSyncServiceTest {
    @TestSetup
    static void createTestData() {
        Account account = new Account(Name = 'Commissionable GP Test Account');
        insert account;

        Product2 product = new Product2(
            Name = 'Commissionable GP Test Product',
            IsActive = true,
            Commissionable__c = true
        );
        insert product;

        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            IsActive = true,
            UnitPrice = 200,
            Purchase_Price__c = 50
        );
    }

    @IsTest
    static void synchronizesInsertUpdateCommissionChangeAndDeleteForLeadOpportunity() {
        Opportunity opportunity = createOpportunity('Lead GP Sync', 'New');
        PricebookEntry pricebookEntry = getPricebookEntry();

        Test.startTest();
        OpportunityLineItem lineItem = new OpportunityLineItem(
            OpportunityId = opportunity.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 200
        );
        insert lineItem;
        Test.stopTest();

        assertSyncedToRollup(opportunity.Id);

        lineItem.UnitPrice = 250;
        update lineItem;
        assertSyncedToRollup(opportunity.Id);

        lineItem.Commission__c = false;
        update lineItem;
        assertSyncedToRollup(opportunity.Id);

        lineItem.Commission__c = true;
        update lineItem;
        assertSyncedToRollup(opportunity.Id);

        delete lineItem;
        assertSyncedToRollup(opportunity.Id);
    }

    @IsTest
    static void synchronizesBulkLineItemsAcrossOpportunities() {
        Opportunity firstOpportunity = createOpportunity('Bulk GP Sync 1', 'New');
        Opportunity secondOpportunity = createOpportunity('Bulk GP Sync 2', 'New');
        PricebookEntry pricebookEntry = getPricebookEntry();

        Test.startTest();
        insert new List<OpportunityLineItem>{
            new OpportunityLineItem(
                OpportunityId = firstOpportunity.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = 2,
                UnitPrice = 200
            ),
            new OpportunityLineItem(
                OpportunityId = secondOpportunity.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = 1,
                UnitPrice = 300
            )
        };
        Test.stopTest();

        assertSyncedToRollup(firstOpportunity.Id);
        assertSyncedToRollup(secondOpportunity.Id);
    }

    @IsTest
    static void preservesSalesOrderOwnedAndClosedOpportunityValues() {
        Opportunity salesOrderOwned = createOpportunity('Sales Order GP', 'New');
        salesOrderOwned.Updated_via_Sales_Order__c = true;
        salesOrderOwned.Commissionable_GP_Currency__c = 777;
        salesOrderOwned.Weighted_Commissionable_GP__c = 333;
        update salesOrderOwned;

        Opportunity closedOpportunity = createOpportunity('Closed GP', 'Closed Won');
        closedOpportunity.Commissionable_GP_Currency__c = 888;
        closedOpportunity.Weighted_Commissionable_GP__c = 444;
        update closedOpportunity;

        PricebookEntry pricebookEntry = getPricebookEntry();
        insert new List<OpportunityLineItem>{
            new OpportunityLineItem(
                OpportunityId = salesOrderOwned.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = 1,
                UnitPrice = 200
            ),
            new OpportunityLineItem(
                OpportunityId = closedOpportunity.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = 1,
                UnitPrice = 200
            )
        };

        assertGP(salesOrderOwned.Id, 777, 333);
        assertGP(closedOpportunity.Id, 888, 444);
    }

    private static Opportunity createOpportunity(String name, String stageName) {
        Id leadRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Lead'
            LIMIT 1
        ].Id;
        Account account = [SELECT Id FROM Account LIMIT 1];

        Opportunity opportunity = new Opportunity(
            Name = name,
            AccountId = account.Id,
            RecordTypeId = leadRecordTypeId,
            StageName = stageName,
            CloseDate = Date.today().addDays(30),
            Probability = 50,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert opportunity;
        return opportunity;
    }

    private static PricebookEntry getPricebookEntry() {
        return [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2.Name = 'Commissionable GP Test Product'
            LIMIT 1
        ];
    }

    private static void assertGP(Id opportunityId, Decimal expectedGP, Decimal expectedWeightedGP) {
        Opportunity actual = [
            SELECT Commissionable_GP_Currency__c, Weighted_Commissionable_GP__c
            FROM Opportunity
            WHERE Id = :opportunityId
        ];
        Assert.areEqual(expectedGP, actual.Commissionable_GP_Currency__c);
        Assert.areEqual(expectedWeightedGP, actual.Weighted_Commissionable_GP__c);
    }

    private static void assertSyncedToRollup(Id opportunityId) {
        Opportunity actual = [
            SELECT Probability, Opp_Commissionable_GP__c,
                Commissionable_GP_Currency__c, Weighted_Commissionable_GP__c
            FROM Opportunity
            WHERE Id = :opportunityId
        ];
        Decimal expectedGP = actual.Opp_Commissionable_GP__c == null
            ? 0
            : actual.Opp_Commissionable_GP__c;
        Decimal expectedWeightedGP = expectedGP * actual.Probability / 100;

        Assert.areEqual(expectedGP, actual.Commissionable_GP_Currency__c);
        Assert.areEqual(expectedWeightedGP, actual.Weighted_Commissionable_GP__c);
    }
}
