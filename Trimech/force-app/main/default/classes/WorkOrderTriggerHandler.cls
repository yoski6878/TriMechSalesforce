public class WorkOrderTriggerHandler {
    
     public static void updateAssetLastPMDate(
        List<WorkOrder> newList,
        Map<Id, WorkOrder> oldMap
    ) {
        Set<Id> workTypeIds = new Set<Id>();

        for (WorkOrder wo : newList) {
            if (wo.WorkTypeId != null) {
                workTypeIds.add(wo.WorkTypeId);
            }
        }

        if (workTypeIds.isEmpty()) return;

        Map<Id, WorkType> workTypeMap = new Map<Id, WorkType>(
            [
                SELECT Id, Name
                FROM WorkType
                WHERE Id IN :workTypeIds
            ]
        );

        Map<Id, Asset> assetsToUpdate = new Map<Id, Asset>();

        for (WorkOrder wo : newList) {

            if (
                wo.WorkTypeId == null ||
                wo.AssetId == null ||
                wo.StartDate == null
            ) continue;

            WorkType wt = workTypeMap.get(wo.WorkTypeId);
            if (wt == null || wt.Name != 'Preventative Maintenance') continue;

            Boolean isInsert = oldMap == null;

            Boolean relevantChange = oldMap != null && (
                oldMap.get(wo.Id).WorkTypeId != wo.WorkTypeId ||
                oldMap.get(wo.Id).AssetId != wo.AssetId ||
                oldMap.get(wo.Id).StartDate != wo.StartDate
            );

            if (isInsert || relevantChange) {
                assetsToUpdate.put(
                    wo.AssetId,
                    new Asset(
                        Id = wo.AssetId,
                        Last_PM_Date__c = Date.valueOf(wo.StartDate)
                    )
                );
            }
        }

        if (!assetsToUpdate.isEmpty()) {
            update assetsToUpdate.values();
        }
    }
}