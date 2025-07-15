/**
* @File Name : CaseCustomDatatableController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : January 7, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 7, 2025 |   | Initial Version
**/

public class CaseCustomDatatableController {
	@AuraEnabled
	public static List<Case> getCaseList(string statusFilter){
		List<Case> caseList = new List<Case>();
		String userId = UserInfo.getUserId();
		if(statusFilter != null && !String.isEmpty(statusFilter)){
			caseList = [SELECT Id, CaseNumber, AccountId , Account.Name, ContactId, Contact.Name, Status, Subject , Priority, CreatedDate, LastModifiedDate FROM Case WHERE Status =: statusFilter AND OwnerId =:userId Order by CreatedDate desc LIMIT 1000];
		}else{
			caseList = [SELECT Id, CaseNumber, AccountId , Account.Name, ContactId, Contact.Name, Status, Subject , Priority, CreatedDate, LastModifiedDate FROM Case WHERE  OwnerId =:userId AND Status != 'Closed' Order by CreatedDate desc  LIMIT 1000];
		}
		return caseList;
	}
}