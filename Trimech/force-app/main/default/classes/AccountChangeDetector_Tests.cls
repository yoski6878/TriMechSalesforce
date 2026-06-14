@IsTest
private class AccountChangeDetector_Tests {

    //Defining list of insignificant fields
    private static Set<String> insignificantFields() {
        return new Set<String>{ 'LastModifiedDate', 'SystemModstamp', 'Phone' };
    }

    @IsTest
    static void test_No_Significant_Change() {
        Account oldA = new Account(Name = 'TestAccount', Phone = '07854967294');
        Account newA = new Account(Name = 'TestAccount', Phone = '07854967294');

        Boolean result = AccountChangeDetector.hasSignificantChanges(oldA, newA, insignificantFields());
        System.assertEquals(false, result, 'No differences should return false.');
    }

    @IsTest
    static void test_Insignificant_Fields_Changed() {
        // Only Phone changes, but Phone is in the exclude set
        Account oldA = new Account(Name = 'TestAccount', Phone = '07854967294');
        Account newA = new Account(Name = 'TestAccount', Phone = '07554443332');

        Boolean result = AccountChangeDetector.hasSignificantChanges(oldA, newA, insignificantFields());
        System.assertEquals(false, result, 'Changes only on excluded (Phone) should return false.');
    }

    @IsTest
    static void test_Significant_Field_Changed() {
        // Name is not excluded, so change should be significant
        Account oldA = new Account(Name = 'TestAccount', Phone = '07854967294');
        Account newA = new Account(Name = 'TestAccount 2', Phone = '07854967294');

        Boolean result = AccountChangeDetector.hasSignificantChanges(oldA, newA, insignificantFields());
        System.assertEquals(true, result, 'Change on non-excluded field (Name) should be significant.');
    }

    @IsTest
    static void test_Null_To_Value() {
        Account oldA = new Account(Name = 'TestAccount');
        Account newA = new Account(Name = 'TestAccount', Phone = '07854967294');

        // For this test, don't exclude Phone so we can assert "null → value" is significant
        Set<String> excludeNoneForPhone = new Set<String>{ 'LastModifiedDate', 'SystemModstamp' };

        Boolean result = AccountChangeDetector.hasSignificantChanges(oldA, newA, excludeNoneForPhone);
        System.assertEquals(true, result, 'Null to value on non-excluded field should be significant.');
    }
}