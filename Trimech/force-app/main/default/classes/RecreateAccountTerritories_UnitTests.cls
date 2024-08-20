@isTest
private class RecreateAccountTerritories_UnitTests {

    @isTest
    private static void testRecalculate(){
        
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LastName = 'last',
            Email = 'testuser123456@test.com',
            Username = 'testuser123456@test.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        insert u;

        Zip_Code__c z1 = new Zip_Code__c(Zip_Code__c = '13219', City__c = 'Syracuse', State__c = 'NY');
        Zip_Code__c z2 = new Zip_Code__c(Zip_Code__c = '02472', City__c = 'Watertown', State__c = 'MA');
        Zip_Code__c z3 = new Zip_Code__c(Zip_Code__c = 'L0L 2M0', City__c = 'Stroud', State__c = 'ON');
        insert new Zip_Code__c[]{z1,z2,z3};
            
        Product_Group__c g1 = new Product_Group__c(Name = 'Group A');
        Product_Group__c g2 = new Product_Group__c(Name = 'Group B');
        insert new Product_Group__c[]{g1,g2};
            
        Territory__c t1 = new Territory__c(Name = 'Territory 1', Product_Group__c = g1.Id);
        Territory__c t2 = new Territory__c(Name = 'Territory 2', Product_Group__c = g1.Id);
        Territory__c t3 = new Territory__c(Name = 'Territory 3', Product_Group__c = g2.Id);
        insert new Territory__c[]{t1,t2,t3};

        Territory_Assignment__c ta1 = new Territory_Assignment__c(Territory__c = t1.id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Inside__c', Assigned_User__c = u.id);
        insert ta1;
            
        Territory_Zip_Code__c tz1 = new Territory_Zip_Code__c(Territory__c = t1.Id, Zip_Code_Record__c = z1.Id);
        Territory_Zip_Code__c tz2 = new Territory_Zip_Code__c(Territory__c = t2.Id, Zip_Code_Record__c = z1.Id);
        Territory_Zip_Code__c tz3 = new Territory_Zip_Code__c(Territory__c = t3.Id, Zip_Code_Record__c = z2.Id);
        Territory_Zip_Code__c tz4 = new Territory_Zip_Code__c(Territory__c = t3.Id, Zip_Code_Record__c = z3.Id);
        insert new Territory_Zip_Code__c[]{tz1,tz2,tz3,tz4};
            
        Account a1 = new Account(Name = 'Eustace Consulting', Sales_Rep_Hardware_Inside__c = u.Id, ShippingPostalCode = '02472', ShippingCountry = 'USA');
        Account a2 = new Account(Name = 'SU', Sales_Rep_Hardware_Outside__c = u.Id, ShippingPostalCode = '13219', ShippingCountry = 'USA');
        /*TH-Account a3 = new Account(Name = 'CA Test', Sales_Rep_Software_Lead_Development__c = u.Id, ShippingPostalCode = 'L0L2M0');
        insert new Account[]{a1,a2,a3}; TH-*/
        insert new Account[]{a1,a2};
            
        System.assertEquals(3,[SELECT Id FROM Account_Territory__c].size());
        
        //delete new List<Account_Territory__c>([SELECT Id FROM Account_Territory__c]);
        
        //System.assertEquals(0,[SELECT Id FROM Account_Territory__c].size());
        
        
        /*List<String> acctIds = new List<String>{a1.id,a2.id,a3.id};
        List<List<String>> args = new  List<List<String>>();
        args.add(acctIds);*/

        List<String> args = new List<String>{u.Id};
        RecreateAccountTerritoriesInvocable.RecreateAccountTerritoresParams params = new RecreateAccountTerritoriesInvocable.RecreateAccountTerritoresParams();
        params.userId = u.id;
        params.taList = new List<Territory_Assignment__c>{ta1};
        
        Test.startTest();
        RecreateAccountTerritoriesInvocable.RecreateAccountTerritoriesInvocable(new List <RecreateAccountTerritoriesInvocable.RecreateAccountTerritoresParams>{params});
        Test.stopTest();
        
        System.assertEquals(3,[SELECT Id FROM Account_Territory__c].size());
    }
}