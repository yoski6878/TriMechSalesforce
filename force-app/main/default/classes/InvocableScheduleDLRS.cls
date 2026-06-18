public with sharing class InvocableScheduleDLRS {
    public class rollupRequests{
        @InvocableVariable
        public List<Id> dlrsList;
        
        @InvocableVariable 
        public Integer delayInterval;

        @InvocableVariable 
        public DateTime scheduledDateTime;
    }
    @InvocableMethod
    public static void makeScheduledCallout(List<rollupRequests> reqs){
        DateTime rollingDateTime = reqs[0].scheduledDateTime;
        Map<Id, dlrs__LookupRollupSummary2__mdt> dlrsList = new Map<Id, dlrs__LookupRollupSummary2__mdt>([SELECT Id, DeveloperName, dlrs__ParentObject__c, dlrs__ChildObject__c, dlrs__FieldToAggregate__c FROM dlrs__LookupRollupSummary2__mdt WHERE Id IN :reqs[0].dlrsList]);
        for(Id dlrs : reqs[0].dlrsList){
            dlrs__LookupRollupSummary2__mdt rec = dlrsList.get(dlrs);
            system.debug(rec.developerName);
            system.debug(rollingDateTime);
            String masterObjectWhere = null;
            String second = '0';
            String minute = String.valueOf(rollingDateTime.minute());
            String hour = String.valueOf(rollingDateTime.hour());
            String day = String.valueOf(rollingDateTime.day());
            String month = String.valueOf(rollingDateTime.month());
            String weekday = '?';
            String uniqueNameForJob = rec.DeveloperName;

            String cronString = second + ' ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ' + weekday;

            System.schedule(
                uniqueNameForJob,
                cronString,
                new LocalRollupCalculateJobSchedulable(
                rec.Id,
                masterObjectWhere
                )
            );

            rollingDateTime = rollingDateTime.addMinutes(reqs[0].delayInterval);            
        }
    }
}