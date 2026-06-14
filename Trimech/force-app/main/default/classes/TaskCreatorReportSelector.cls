public with sharing class TaskCreatorReportSelector {
    @AuraEnabled(cacheable=true)
    public static List<ReportInfo> getAvailableReports() {
        List<ReportInfo> reports = new List<ReportInfo>();
        // Query for reports owned by the user (most reliable approach)
        // This is the most straightforward and supported approach for fetching reports
        for (Report r : [SELECT Id, Name FROM Report ORDER BY CreatedDate DESC]) {
            reports.add(new ReportInfo(r.Id, r.Name));
        }
        return reports;
    }

    public class ReportInfo {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        public ReportInfo(Id id, String name) {
            this.Id = id;
            this.Name = name;
        }
    }
}