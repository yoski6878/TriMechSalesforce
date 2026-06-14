@IsTest
private class CanadaAccountSubsidiaryBatchTest {

    private static final String SUBSIDIARY_TRIMECH = 'TriMech Solutions LLC';
    private static final String SUBSIDIARY_JAVELIN = 'Javelin Technologies Inc.';

    @TestSetup
    static void setup() {
        List<Account> accts = new List<Account>();

        // Should be updated: explicit Canadian country, blank NetSuite Id, TriMech subsidiary.
        accts.add(new Account(Name = 'CA Country', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = 'Canada', ShippingPostalCode = 'M5V 2T6'));
        accts.add(new Account(Name = 'CAN Country', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = 'CAN', ShippingPostalCode = 'K1A0B1'));

        // Should be updated: blank country but Canadian postal code (contains letters).
        accts.add(new Account(Name = 'Blank Country Letter Postal', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = null, ShippingPostalCode = 'H2X 1Y4'));

        // Should NOT be updated: blank country, numeric (US-style) postal code.
        accts.add(new Account(Name = 'Blank Country Numeric Postal', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = null, ShippingPostalCode = '90210'));

        // Should NOT be updated: US account.
        accts.add(new Account(Name = 'US Account', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = 'United States', ShippingPostalCode = '10001'));

        // Should NOT be updated: already synced to NetSuite.
        accts.add(new Account(Name = 'Synced Canadian', Subsidiary__c = SUBSIDIARY_TRIMECH,
            ShippingCountry = 'Canada', ShippingPostalCode = 'V6B 1A1',
            celigo_sfnsio__NetSuite_Id__c = 'NS-12345'));

        insert accts;
    }

    @IsTest
    static void it_updates_only_unsynced_canadian_trimech_accounts() {
        Test.startTest();
        Database.executeBatch(new CanadaAccountSubsidiaryBatch(), 200);
        Test.stopTest();

        Map<String, Account> byName = new Map<String, Account>();
        for (Account acc : [
            SELECT Name, Subsidiary__c, CurrencyIsoCode
            FROM Account
        ]) {
            byName.put(acc.Name, acc);
        }

        Assert.areEqual(SUBSIDIARY_JAVELIN, byName.get('CA Country').Subsidiary__c, 'Canada country -> Javelin');
        Assert.areEqual('CAD', byName.get('CA Country').CurrencyIsoCode, 'Canada country -> CAD');

        Assert.areEqual(SUBSIDIARY_JAVELIN, byName.get('CAN Country').Subsidiary__c, 'CAN country -> Javelin');

        Assert.areEqual(SUBSIDIARY_JAVELIN, byName.get('Blank Country Letter Postal').Subsidiary__c,
            'Blank country with letter postal -> Javelin');
        Assert.areEqual('CAD', byName.get('Blank Country Letter Postal').CurrencyIsoCode,
            'Blank country with letter postal -> CAD');

        Assert.areEqual(SUBSIDIARY_TRIMECH, byName.get('Blank Country Numeric Postal').Subsidiary__c,
            'Numeric postal stays TriMech');
        Assert.areEqual(SUBSIDIARY_TRIMECH, byName.get('US Account').Subsidiary__c,
            'US account stays TriMech');
        Assert.areEqual(SUBSIDIARY_TRIMECH, byName.get('Synced Canadian').Subsidiary__c,
            'Already-synced account is excluded');
    }

    @IsTest
    static void it_can_be_scheduled() {
        Test.startTest();
        String jobId = System.schedule(
            'CanadaAccountSubsidiaryBatchTest Job',
            '0 0 6 * * ?',
            new CanadaAccountSubsidiaryBatch());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 6 * * ?', ct.CronExpression, 'Job scheduled with expected CRON expression');
    }

    @IsTest
    static void it_classifies_accounts_correctly() {
        Assert.isTrue(CanadaAccountSubsidiaryBatch.isCanadianAccount(
            new Account(ShippingCountry = 'ca')), 'ca is Canadian');
        Assert.isTrue(CanadaAccountSubsidiaryBatch.isCanadianAccount(
            new Account(ShippingCountry = null, ShippingPostalCode = 'H2X 1Y4')),
            'blank country + letter postal is Canadian');
        Assert.isFalse(CanadaAccountSubsidiaryBatch.isCanadianAccount(
            new Account(ShippingCountry = null, ShippingPostalCode = '90210')),
            'blank country + numeric postal is not Canadian');
        Assert.isFalse(CanadaAccountSubsidiaryBatch.isCanadianAccount(
            new Account(ShippingCountry = 'United States', ShippingPostalCode = '10001')),
            'US is not Canadian');
    }
}