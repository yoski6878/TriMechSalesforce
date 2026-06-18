/**
* @File Name : DoNotSendSurveyController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : February 10, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 10, 2025 |   | Initial Version
**/
public class DoNotSendSurveyController {
    @AuraEnabled(cacheable=true)
    public static Boolean hasPermission() {
        return (FeatureManagement.checkPermission('Do_Not_Send_Survey_Permission'));
    }
}