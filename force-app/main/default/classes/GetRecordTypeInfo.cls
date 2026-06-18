public with sharing class GetRecordTypeInfo {
    
    @AuraEnabled
    public static String getRecordTypeDeveloperName(Id recordTypeId) {
        if (recordTypeId == null) {
            return null;
        }
        
        RecordType rt = [SELECT DeveloperName FROM RecordType WHERE Id = :recordTypeId LIMIT 1];
        return rt != null ? rt.DeveloperName : null;
    }
    
    @AuraEnabled
    public static Boolean isCompetitorAsset(Id recordTypeId) {
        String developerName = getRecordTypeDeveloperName(recordTypeId);
        return developerName != null && developerName.equalsIgnoreCase('Competitor_Assets');
    }
}