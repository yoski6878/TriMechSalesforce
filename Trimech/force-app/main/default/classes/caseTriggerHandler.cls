public class caseTriggerHandler {
    
    public static void setCaseValue(List<Case> newList , List<Case>oldList, Map<Id, Case> newMap , Map<Id, Case> oldMap ){
        try{
            Integer fieldLength = 255;
			fieldLength = Case.Description_Highlights__c.getDescribe().getLength();            
            for(Case cs : newList){
                if(cs.description != null && cs.description != ''){
	                cs.Description_Highlights__c = cs.description.length() > fieldLength ? cs.description.substring(0,fieldLength) : cs.description;
                }else{
                    cs.Description_Highlights__c = null;
                }
                if (Trigger.isInsert) {
                    cs.Status_Last_Modified_Date__c = Date.today();
                } else if (Trigger.isUpdate) {
                    Case oldCase = oldMap.get(cs.Id);
                    if (cs.Status != oldCase.Status) {
                        cs.Status_Last_Modified_Date__c = Date.today();
                    }
                }


            }
        }catch(exception e){
            System.debug(e.getMessage());
        }        
    }
    
    private static Id bhId;

    private static Id getBusinessHoursId() {
        if (bhId == null) {
            bhId = [
                SELECT Id
                FROM BusinessHours
                WHERE Name = 'USA EST'
                LIMIT 1
            ].Id;
        }
        return bhId;
    }

    public static void updateInProgressTime(List<Case> newList, Map<Id, Case> oldMap) {
        Id businessHoursId = getBusinessHoursId();
        Datetime nowDt = System.now();

        for (Case c : newList) {
            Case oldC = oldMap != null ? oldMap.get(c.Id) : null;

            Boolean oldWasInProgress = oldC != null && oldC.Status == 'In Progress';
            Boolean newIsInProgress  = c.Status == 'In Progress';

            // 1) Entering In Progress
            if (newIsInProgress && (oldC == null || !oldWasInProgress)) {
                // Only stamp if not already set
                if (c.In_Progress_Start__c == null) {
                    c.In_Progress_Start__c = nowDt;
                }
            }

            if (oldWasInProgress && (!newIsInProgress || c.IsClosed)) {
                if (oldC.In_Progress_Start__c != null) {
                    Long diffMs = BusinessHours.diff(
                        businessHoursId,
                        oldC.In_Progress_Start__c,
                        nowDt
                    );
                    Decimal diffHours = diffMs == null ? 0 : (Decimal)diffMs / (1000 * 60 * 60);
                    if (c.Total_In_Progress_Hours__c == null) {
                        c.Total_In_Progress_Hours__c = 0;
                    }
                    c.Total_In_Progress_Hours__c += diffHours;
                    c.In_Progress_Start__c = null;
                }
            }
        }
    }
    
    public static void updateLatestPMDate(List<Case> newList, Map<Id, Case> oldMap) {
        Map<Id, Asset> assetsToUpdate = new Map<Id, Asset>();
        for (Case c : newList) {

            if (c.AssetId == null) continue;

            Boolean assetChanged = oldMap != null
                && oldMap.get(c.Id).AssetId != c.AssetId;

            Boolean typeChangedToPM = oldMap != null
                && oldMap.get(c.Id).Type != 'Printer Preventative Maintenance'
                && c.Type == 'Printer Preventative Maintenance';

            Boolean isNewPMCase = oldMap == null
                && c.Type == 'Printer Preventative Maintenance'
                && c.AssetId != null;

            if (assetChanged || typeChangedToPM || isNewPMCase) {
                if (c.Type == 'Printer Preventative Maintenance') {
                    assetsToUpdate.put(
                        c.AssetId,
                        new Asset(
                            Id = c.AssetId,
                            Last_PM_Date__c = Date.valueOf(c.CreatedDate)
                        )
                    );
                }
            }
        }

        if (!assetsToUpdate.isEmpty()) {
            update assetsToUpdate.values();
        }        
    }

}