/**
* @File Name : RunAccountNukeBatchAction.cls
* @Description : Single-purpose Invocable Apex action backing the "Run NUKE
*   Account Cleanup" Screen Flow / Quick Action button. Kicks off
*   NukeAccountBatch, which permanently deletes every Account flagged
*   NUKE__c = true (subject to its own 500-record safety cap).
* @Author :
* @Last Modified By :
* @Last Modified On :
**/

public without sharing class RunAccountNukeBatchAction {
    @InvocableMethod(label='Run NUKE Account Cleanup Batch' description='Kicks off NukeAccountBatch to permanently delete every Account flagged NUKE__c = true')
    public static void run() {
        Database.executeBatch(new NukeAccountBatch(), 50);
    }
}
