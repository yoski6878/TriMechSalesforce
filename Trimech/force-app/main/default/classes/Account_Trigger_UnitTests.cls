/**************************************************************
 * This test class is used to test the trigger and class
 * for the Account object.
 * 
 ***************************************************************/
@isTest
public class Account_Trigger_UnitTests {
    
    @isTest
    public static void createProfile(){
        
        Section_Template__c st = new Section_Template__c(Name = '1');
        insert new Section_Template__c[]{st};
        
        Question_Template__c qt1 = new Question_Template__c(Question__c = '1', Section_Template__c = st.Id, Active__c = true);
        Question_Template__c qt2 = new Question_Template__c(Question__c = '2', Section_Template__c = st.Id, Active__c = true);
        Question_Template__c qt3 = new Question_Template__c(Question__c = '3', Section_Template__c = st.Id, Active__c = false);
        insert new Question_Template__c[]{qt1,qt2,qt3};
        
        Account a1 = new Account(Name = 'A');
        Account a2 = new Account(Name = 'B');
        insert new Account[]{a1,a2};
        
    }
    
    @isTest
    public static void testSetAccountTeam(){
        
        User iu = [SELECT Id FROM User WHERE IsActive = false LIMIT 1];
        
        Account a1 = new Account(Name = 'Eustace Consulting A', Sales_Rep_Hardware_Inside__c = UserInfo.getUserId());
        Account a2 = new Account(Name = 'Eustace Consulting B', Sales_Rep_Hardware_Inside__c = iu.Id);
        insert new Account[]{a1,a2};
        
        System.assertEquals(1,[SELECT Id FROM AccountTeamMember WHERE UserId = :UserInfo.getUserId()].size());
        
        a1.Sales_Rep_Hardware_Inside__c = null;
        a1.Sales_Rep_Hardware_Outside__c = UserInfo.getUserId();
        a1.Dedicated_SolidCAM_Rep__c = UserInfo.getUserId();
        a1.Sales_Rep_Software__c = UserInfo.getUserId();
        a2.Sales_Rep_Hardware_Inside__c = null;
        a2.Sales_Rep_Hardware_Outside__c = UserInfo.getUserId();
        a2.Sales_Rep_SolidCAM__c = UserInfo.getUserId();
        a2.Dedicated_Sales_Rep_Software__c = UserInfo.getUserId();
        update new Account[]{a1,a2};
        
        System.assertEquals(2,[SELECT Id FROM AccountTeamMember WHERE UserId = :UserInfo.getUserId()].size());
    }
    
    @isTest
    public static void testCreateAccountTerritories(){
    
        Zip_Code__c z1 = new Zip_Code__c(Zip_Code__c = '13219', City__c = 'Syracuse', State__c = 'NY');
        Zip_Code__c z2 = new Zip_Code__c(Zip_Code__c = '02472', City__c = 'Watertown', State__c = 'MA');
        Zip_Code__c z3 = new Zip_Code__c(Zip_Code__c = 'L0L 2M0', City__c = 'Stroud', State__c = 'ON');
        insert new Zip_Code__c[]{z1,z2,z3};
            
        Product_Group__c g1 = new Product_Group__c(Name = 'Group A');
        Product_Group__c g2 = new Product_Group__c(Name = 'Group B');
        Product_Group__c g3 = new Product_Group__c(Name = 'Group C');
        insert new Product_Group__c[]{g1,g2,g3};
            
        Territory__c t1 = new Territory__c(Name = 'Territory 1', Product_Group__c = g1.Id);
        Territory__c t2 = new Territory__c(Name = 'Territory 2', Product_Group__c = g1.Id);
        Territory__c t3 = new Territory__c(Name = 'Territory 3', Product_Group__c = g2.Id);
        Territory__c t4 = new Territory__c(Name = 'Territory 4', Product_Group__c = g3.Id);
        insert new Territory__c[]{t1,t2,t3,t4};
            
        Territory_Zip_Code__c tz1 = new Territory_Zip_Code__c(Territory__c = t1.Id, Zip_Code_Record__c = z1.Id);
        Territory_Zip_Code__c tz2 = new Territory_Zip_Code__c(Territory__c = t2.Id, Zip_Code_Record__c = z1.Id);
        Territory_Zip_Code__c tz3 = new Territory_Zip_Code__c(Territory__c = t3.Id, Zip_Code_Record__c = z2.Id);
        Territory_Zip_Code__c tz4 = new Territory_Zip_Code__c(Territory__c = t4.Id, Zip_Code_Record__c = z3.Id);
        insert new Territory_Zip_Code__c[]{tz1,tz2,tz3,tz4};
            
        Account a1 = new Account(Name = 'Eustace Consulting', ShippingPostalCode = '02472');
        Account a2 = new Account(Name = 'SU', ShippingPostalCode = '13219');
        Account a3 = new Account(Name = 'CA Test', ShippingPostalCode = 'L0L2M0');
        insert new Account[]{a1,a2,a3};
            
        System.assertEquals(4,[SELECT Id FROM Account_Territory__c].size());
        
        a1.ShippingPostalCode = '13219';
        a2.ShippingPostalCode = 'L0L2M0';
        a3.ShippingPostalCode = '02472';
        update new Account[]{a1,a2};
            
        System.assertEquals(4,[SELECT Id FROM Account_Territory__c].size());
    }
}