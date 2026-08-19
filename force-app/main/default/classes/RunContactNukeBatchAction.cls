/**
* @File Name : RunContactNukeBatchAction.cls
* @Description : Single-purpose Invocable Apex action backing the "Run NUKE
*   Contact Cleanup" Screen Flow / Quick Action button. Kicks off
*   NukeContactBatch, which permanently deletes every Contact flagged
*   NUKE__c = true (subject to its own 500-record safety cap).
* @Author :
* @Last Modified By :
* @Last Modified On :
**/

public without sharing class RunContactNukeBatchAction {
    @InvocableMethod(label='Run NUKE Contact Cleanup Batch' description='Kicks off NukeContactBatch to permanently delete every Contact flagged NUKE__c = true')
    public static void run() {
        Database.executeBatch(new NukeContactBatch(), 100);
    }
}
