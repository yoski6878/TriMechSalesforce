/**
 * Daily automation that replicates the "Canada Accts in TM Subsidiary" report.
 *
 * Targets Accounts that are NOT yet synced to NetSuite, are still flagged as the
 * TriMech Solutions LLC subsidiary, but are really Canadian (either Shipping
 * Country is Canada/CAN/CA, or Shipping Country is blank and the postal code
 * contains a letter — the hallmark of a Canadian postal code). Those accounts are
 * re-pointed to the Javelin Technologies Inc. subsidiary with CAD currency.
 *
 * Report logic reproduced: 1 AND 2 AND (3 OR (4 AND 5))
 *   1) NetSuite Id (IO) is blank
 *   2) Subsidiary = TriMech Solutions LLC
 *   3) Shipping Country in (Canada, CAN, CA)
 *   4) Shipping Country is blank
 *   5) Shipping Postal Code contains a letter
 */
public with sharing class CanadaAccountSubsidiaryBatch implements Database.Batchable<SObject>, Schedulable {

    @TestVisible private static final String SUBSIDIARY_TRIMECH = 'TriMech Solutions LLC';
    @TestVisible private static final String SUBSIDIARY_JAVELIN = 'Javelin Technologies Inc.';
    @TestVisible private static final String TARGET_CURRENCY = 'CAD';

    // Lower-cased Shipping Country values that mean "Canada".
    @TestVisible private static final Set<String> CANADA_VARIANTS = new Set<String>{ 'canada', 'can', 'ca' };

    // Original-case list used in the SOQL filter (SOQL string comparison is case-insensitive).
    private static final List<String> CANADA_COUNTRY_FILTER = new List<String>{ 'Canada', 'CAN', 'CA' };

    // Canadian postal codes contain letters; US/numeric ZIP codes do not.
    private static final Pattern LETTER_PATTERN = Pattern.compile('.*[A-Za-z].*');

    /**
     * Schedulable entry point. Kick off the batch when the daily CRON job fires.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Subsidiary__c, CurrencyIsoCode, ShippingCountry, ShippingPostalCode
            FROM Account
            WHERE celigo_sfnsio__NetSuite_Id__c = null
              AND Subsidiary__c = :SUBSIDIARY_TRIMECH
              AND (ShippingCountry IN :CANADA_COUNTRY_FILTER OR ShippingCountry = null)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Account> toUpdate = new List<Account>();
        for (Account acc : scope) {
            if (!isCanadianAccount(acc)) {
                continue;
            }
            acc.Subsidiary__c = SUBSIDIARY_JAVELIN;
            acc.CurrencyIsoCode = TARGET_CURRENCY;
            toUpdate.add(acc);
        }

        if (toUpdate.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.update(toUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'CanadaAccountSubsidiaryBatch failed to update Account ' + toUpdate[i].Id +
                    ': ' + results[i].getErrors());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // No post-processing required.
    }

    /**
     * Mirrors report filter (3 OR (4 AND 5)): a Canadian Shipping Country, or a blank
     * country with a postal code that contains a letter (Canadian postal code pattern).
     */
    @TestVisible
    private static Boolean isCanadianAccount(Account acc) {
        if (String.isNotBlank(acc.ShippingCountry)) {
            return CANADA_VARIANTS.contains(acc.ShippingCountry.toLowerCase().trim());
        }
        return String.isNotBlank(acc.ShippingPostalCode)
            && LETTER_PATTERN.matcher(acc.ShippingPostalCode).matches();
    }
}