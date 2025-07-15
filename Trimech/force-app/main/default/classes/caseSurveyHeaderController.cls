/**
* @File Name : caseSurveyHeaderController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 29, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 29, 2024 |   | Initial Version
**/
public without sharing class caseSurveyHeaderController {
	@AuraEnabled
	public static caseRecordWrapper getCaseDetails(String caseId){
		caseRecordWrapper caseRecord = new caseRecordWrapper();
		if(caseId != null && caseId != '' ){
			List<Case> caseList = [Select CaseNumber, contact.Name, Assigned_Analyst__c, Account.Name,  subject FROM Case where Id =:caseId ];
			caseRecord.contactName = caseList[0].contact.Name;
			caseRecord.accountName = caseList[0].Account.Name;
			caseRecord.ownerName = caseList[0].Assigned_Analyst__c;
			caseRecord.CaseNumber = caseList[0].CaseNumber;
			caseRecord.subject = caseList[0].subject;

			List<SurveySubject> getLatestSubject = [SELECT Id, ParentId FROM SurveySubject  WHERE SubjectId =:caseId AND Parent.Type = 'SurveyInvitation' ORDER BY CreatedDate desc LIMIT 1];
			
			if(getLatestSubject.size() > 0){
				List<SurveyInvitation> getSurveyInvitation = [SELECT Id, InvitationLink FROM SurveyInvitation WHERE Id =: getLatestSubject[0].ParentId LIMIT 1 ];
				caseRecord.surveyURL = getSurveyInvitation[0].InvitationLink;
			}
		}
		return caseRecord;
	}

	public class caseRecordWrapper
    {
        @AuraEnabled public String contactName {get;set;}
        @AuraEnabled public String accountName {get;set;}
        @AuraEnabled public String ownerName {get;set;}
        @AuraEnabled public String CaseNumber {get;set;}
        @AuraEnabled public String subject {get;set;}
		@AuraEnabled public String surveyURL{get;set;}
    }
}