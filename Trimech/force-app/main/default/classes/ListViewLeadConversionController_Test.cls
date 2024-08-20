@isTest 
public class ListViewLeadConversionController_Test {

    @isTest
    static void testListView(){
        List<Lead> leads = new List<Lead>();
        Lead l1 = new Lead();
        l1.firstName = 'test';
        l1.lastName = 'lead1';
        l1.email = 'testlead1@example.com';
        l1.company = 'testCompany1';
        leads.add(l1);
        Lead l2 = new Lead();
        l2.firstName = 'test';
        l2.lastName = 'lead2';
        l2.email = 'testlead2@example.com';
        l2.company = 'testCompany2';
        leads.add(l2);
        insert leads;
        
        Test.startTest();
        Test.setCurrentPage(Page.PardotLeadConversion);
        ApexPages.StandardSetController sc = new ApexPages.StandardSetController(leads);
        sc.setSelected(leads);
        ListViewLeadConversionController ext = new ListViewLeadConversionController(sc);
        Test.stopTest();
    }
 }