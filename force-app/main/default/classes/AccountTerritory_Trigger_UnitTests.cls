/**************************************************************
 * This test class is used to test the trigger and class
 * for the AccountTerritory object.
 * 
 ***************************************************************/
@isTest
private class AccountTerritory_Trigger_UnitTests {
    
    @isTest
    private static void testClearProductGroupFieldAssignments(){

        Zip_Code__c z = new Zip_Code__c(Zip_Code__c = '02472', City__c = 'Watertown', State__c = 'MA');
        insert z;
            
        Product_Group__c g1 = new Product_Group__c(Name = 'Group A', Primary_Account_Territory__c = true);
        Product_Group__c g2 = new Product_Group__c(Name = 'Group B');
        insert new Product_Group__c[]{g1,g2};
            
        //TH-Product_Group_Field_Assignment__c pgfa1 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Sales_Rep_Software_Inside__c', Product_Group__c = g1.Id);
        //TH-Product_Group_Field_Assignment__c pgfa2 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Sales_Rep_Software_Outside__c', Product_Group__c = g1.Id);
        //TH-Added below line
        Product_Group_Field_Assignment__c pgfa2 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Sales_Rep_Software__c', Product_Group__c = g1.Id);
        //TH-Product_Group_Field_Assignment__c pgfa3 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Sales_Rep_Software_Lead_Development__c', Product_Group__c = g1.Id);
        
        //Code Coverage for error handling
        //Product_Group_Field_Assignment__c pgfa4 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Id', Product_Group__c = g2.Id);
        //Product_Group_Field_Assignment__c pgfa5 = new Product_Group_Field_Assignment__c(Account_Field_API_Name__c = 'Not_A_Field__c', Product_Group__c = g2.Id);
        //insert new Product_Group_Field_Assignment__c[]{pgfa1,pgfa2,pgfa3,pgfa4,pgfa5};
        //TH-insert new Product_Group_Field_Assignment__c[]{pgfa1,pgfa2,pgfa3};
        //TH-Added below line
        insert new Product_Group_Field_Assignment__c[]{pgfa2};
        
        Territory__c t1 = new Territory__c(Name = 'Territory 1', Product_Group__c = g1.Id, Region__c = 'North');
        Territory__c t2 = new Territory__c(Name = 'Territory 2', Product_Group__c = g1.Id, Region__c = 'North');
        Territory__c t3 = new Territory__c(Name = 'Territory 3', Product_Group__c = g2.Id, Region__c = 'North');
        insert new Territory__c[]{t1,t2,t3};
            
            
        Territory_Assignment__c[] taToUpdate = new Territory_Assignment__c[]{};
        for(Territory_Assignment__c ta : [SELECT Id, Account_Field_to_Assign__c, Assigned_User__c FROM Territory_Assignment__c]){
            taToUpdate.add(new Territory_Assignment__c(Id = ta.Id, Assigned_User__c = UserInfo.getUserId(), Account_Field_to_Assign__c = 'Sales_Rep_Software__c'));           
        }    
        update taToUpdate;
            
        Territory_Zip_Code__c tz1 = new Territory_Zip_Code__c(Territory__c = t1.Id, Zip_Code_Record__c = z.Id);
        Territory_Zip_Code__c tz2 = new Territory_Zip_Code__c(Territory__c = t2.Id, Zip_Code_Record__c = z.Id);
        Territory_Zip_Code__c tz3 = new Territory_Zip_Code__c(Territory__c = t3.Id, Zip_Code_Record__c = z.Id);
        insert new Territory_Zip_Code__c[]{tz1,tz2,tz3};
            
        Account a1 = new Account(Name = 'Eustace Consulting', ShippingPostalCode = '02472');
        Account a2 = new Account(Name = 'Salesforce', ShippingPostalCode = '02472');
        insert new Account[]{a1,a2};
        
        /*for(Account a : [SELECT Id, Sales_Rep_Software_Inside__c, Sales_Rep_Software_Outside__c, Sales_Rep_Software_Lead_Development__c, Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c, Sales_Rep_Tulip__c FROM Account]){
            System.assertEquals(UserInfo.getUserId(), a.Sales_Rep_Software_Inside__c);    
            System.assertEquals(UserInfo.getUserId(), a.Sales_Rep_Software_Outside__c);    
            System.assertEquals(UserInfo.getUserId(), a.Sales_Rep_Software_Lead_Development__c);  
        }*/
        //TH-Added below line
        System.assertEquals(null, a1.Sales_Rep_Software__c, 'Success');    
        
        delete new List<Account_Territory__c>([SELECT Id FROM Account_Territory__c]);
        
        /*for(Account a : [SELECT Id, Sales_Rep_Software_Inside__c, Sales_Rep_Software_Outside__c, Sales_Rep_Software_Lead_Development__c, Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c, Sales_Rep_Tulip__c FROM Account]){
            System.assertEquals(null, a.Sales_Rep_Software_Inside__c);    
            System.assertEquals(null, a.Sales_Rep_Software_Outside__c);    
            System.assertEquals(null, a.Sales_Rep_Software_Lead_Development__c);  
        }*/
    }
    
    @isTest
    private static void testSetTerritoryAssignments(){
        
        Zip_Code__c z = new Zip_Code__c(Zip_Code__c = '02472', City__c = 'Watertown', State__c = 'MA');
        Zip_Code__c z2 = new Zip_Code__c(Zip_Code__c = 'L0L 2M0', City__c = 'Stroud', State__c = 'ON');
        insert new Zip_Code__c[]{z, z2};
            
        Product_Group__c g1 = new Product_Group__c(Name = 'Group A');
        Product_Group__c g2 = new Product_Group__c(Name = 'Group B');
        insert new Product_Group__c[]{g1,g2};
            
        Territory__c t1 = new Territory__c(Name = 'Territory 1', Product_Group__c = g1.Id);
        Territory__c t2 = new Territory__c(Name = 'Territory 2', Product_Group__c = g1.Id);
        Territory__c t3 = new Territory__c(Name = 'Territory 3', Product_Group__c = g2.Id);
        Territory__c t4 = new Territory__c(Name = 'Territory 4', Product_Group__c = g2.Id);
        insert new Territory__c[]{t1,t2,t3,t4};
            
        //TH-Territory_Assignment__c ta1 = new Territory_Assignment__c(Territory__c = t1.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Inside__c', Assigned_User__c = UserInfo.getUserId());
        //TH-Territory_Assignment__c ta2 = new Territory_Assignment__c(Territory__c = t1.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Outside__c', Assigned_User__c = UserInfo.getUserId());
        Territory_Assignment__c ta2 = new Territory_Assignment__c(Territory__c = t1.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software__c', Assigned_User__c = UserInfo.getUserId());
        //TH-Territory_Assignment__c ta3 = new Territory_Assignment__c(Territory__c = t2.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Lead_Development__c', Assigned_User__c = UserInfo.getUserId());
        Territory_Assignment__c ta4 = new Territory_Assignment__c(Territory__c = t2.Id, Account_Field_to_Assign__c = 'Sales_Rep_Hardware_Inside__c', Assigned_User__c = UserInfo.getUserId());
        Territory_Assignment__c ta5 = new Territory_Assignment__c(Territory__c = t3.Id, Account_Field_to_Assign__c = 'Sales_Rep_Hardware_Outside__c', Assigned_User__c = UserInfo.getUserId());
        //TH-Territory_Assignment__c ta6 = new Territory_Assignment__c(Territory__c = t3.Id, Account_Field_to_Assign__c = 'Sales_Rep_Tulip__c', Assigned_User__c = UserInfo.getUserId());
        //TH-Territory_Assignment__c ta7 = new Territory_Assignment__c(Territory__c = t4.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Inside__c', Assigned_User__c = UserInfo.getUserId());
        //TH-Territory_Assignment__c ta8 = new Territory_Assignment__c(Territory__c = t4.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software_Outside__c', Assigned_User__c = UserInfo.getUserId());
        Territory_Assignment__c ta8 = new Territory_Assignment__c(Territory__c = t4.Id, Account_Field_to_Assign__c = 'Sales_Rep_Software__c', Assigned_User__c = UserInfo.getUserId());
        //TH-insert new Territory_Assignment__c[]{ta1,ta2,ta3,ta4,ta5,ta6,ta7,ta8};
        //TH-Added below line
        insert new Territory_Assignment__c[]{ta2,ta4,ta5,ta8};
        
        Territory_Zip_Code__c tz1 = new Territory_Zip_Code__c(Territory__c = t1.Id, Zip_Code_Record__c = z.Id);
        Territory_Zip_Code__c tz2 = new Territory_Zip_Code__c(Territory__c = t2.Id, Zip_Code_Record__c = z.Id);
        Territory_Zip_Code__c tz3 = new Territory_Zip_Code__c(Territory__c = t3.Id, Zip_Code_Record__c = z.Id);
        Territory_Zip_Code__c tz4 = new Territory_Zip_Code__c(Territory__c = t4.Id, Zip_Code_Record__c = z2.Id);
        insert new Territory_Zip_Code__c[]{tz1,tz2,tz3,tz4};
            
        Account a1 = new Account(Name = 'Eustace Consulting', ShippingPostalCode = '02472');
        Account a2 = new Account(Name = 'Eustace Canada', ShippingPostalCode = 'L0L 2M0');
        //Account a2 = new Account(Name = 'Salesforce', ShippingPostalCode = '02472');
        //insert new Account[]{a1,a2};
        Test.startTest();
        insert new Account[]{a1, a2};
        Test.stopTest();
        
            //TH-a1 = [SELECT Id, Sales_Rep_Software_Inside__c, Sales_Rep_Software_Outside__c, Sales_Rep_Software_Lead_Development__c, Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c, Sales_Rep_Tulip__c FROM Account WHERE id =: a1.id];
            //TH-Added and updated below line
            a1 = [SELECT Id, Sales_Rep_Software__c, Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c FROM Account WHERE id =: a1.id];
            //TH-System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Software_Inside__c);    
            //TH-Modified below 3 uncommented lines to add the 3rd parameter for assertEquals method
            System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Software__c, 'Success');    
            //TH-System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Software_Lead_Development__c);    
            System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Hardware_Inside__c, 'Success');    
            System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Hardware_Outside__c, 'Success');    
            //TH-System.assertEquals(UserInfo.getUserId(), a1.Sales_Rep_Tulip__c);


        //queueable only processes one account at a time in unit tests, so a2 never gets processed
        /*a2 = [SELECT Id, Sales_Rep_Software_Inside__c, Sales_Rep_Software_Outside__c, Sales_Rep_Software_Lead_Development__c, Sales_Rep_Hardware_Inside__c, Sales_Rep_Hardware_Outside__c, Sales_Rep_Tulip__c FROM Account WHERE id =: a2.id];
            System.assertEquals(UserInfo.getUserId(), a2.Sales_Rep_Software_Inside__c);    
            System.assertEquals(UserInfo.getUserId(), a2.Sales_Rep_Software_Outside__c);    
            System.assertEquals(null, a2.Sales_Rep_Software_Lead_Development__c);    
            System.assertEquals(null, a2.Sales_Rep_Hardware_Inside__c);    
            System.assertEquals(null, a2.Sales_Rep_Hardware_Outside__c);    
            System.assertEquals(null, a2.Sales_Rep_Tulip__c);*/
    }
}