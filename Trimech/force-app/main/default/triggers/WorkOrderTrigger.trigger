trigger WorkOrderTrigger on WorkOrder (after insert, after update) {
    if (Trigger.isAfter) {
        WorkOrderTriggerHandler.updateAssetLastPMDate(
            Trigger.new,
            Trigger.oldMap
        );
    }
}