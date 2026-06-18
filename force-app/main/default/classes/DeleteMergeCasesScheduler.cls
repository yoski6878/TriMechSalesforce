/**
* @File Name : DeleteMergeCasesScheduler.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 24, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 24, 2025 |   | Initial Version
**/

global class DeleteMergeCasesScheduler implements Schedulable {
	global void execute(SchedulableContext sc) {
        DeleteMergedCaseBatch batch = new DeleteMergedCaseBatch();
        Database.executeBatch(batch, 200);
    }
}