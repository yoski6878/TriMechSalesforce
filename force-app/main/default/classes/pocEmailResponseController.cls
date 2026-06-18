/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : pocEmailResponseController
 * Author          : <YourName>
 * Created Date    : Feb 24, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 24, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 24, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public without sharing class pocEmailResponseController {

    @AuraEnabled
    public static void updateCase(String caseId, String actionValue) {

        if(String.isBlank(caseId) || String.isBlank(actionValue)) {
            throw new AuraHandledException('Invalid parameters');
        }

        Case c = [SELECT Id, POC_Email_Update__c 
                  FROM Case 
                  WHERE Id = :caseId 
                  LIMIT 1];

        if(actionValue == 'Close'){
            c.POC_Email_Update__c = 'Close';
        }
        else if(actionValue == 'NeedHelp'){
            c.POC_Email_Update__c = 'Need Help';
        }

        update c;
    }
}