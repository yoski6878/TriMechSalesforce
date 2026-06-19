@isTest
public with sharing class TaskCreatorReportSelectorTest {
    @isTest
    static void testGetAvailableReports() {
        Test.startTest();
        List<Object> reports = TaskCreatorReportSelector.getAvailableReports();
        System.assert(reports != null);
        // Access ReportInfo properties for coverage
        for (Object o : reports) {
            // Cast to Map<String, Object> since AuraEnabled inner classes are returned as maps
            Map<String, Object> info = (Map<String, Object>)o;
            Object id = info.get('Id');
            Object name = info.get('Name');
            System.assert(id != null || name != null);
        }
        // Directly instantiate ReportInfo for coverage
        TaskCreatorReportSelector.ReportInfo testInfo = new TaskCreatorReportSelector.ReportInfo('00O000000000001', 'Test Report');
        System.assertEquals('00O000000000001', testInfo.Id);
        System.assertEquals('Test Report', testInfo.Name);
        Test.stopTest();
    }
}