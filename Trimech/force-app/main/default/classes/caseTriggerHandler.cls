public class caseTriggerHandler {
    
    public static void setCaseValue(List<Case> newList , List<Case>oldList, Map<Id, Case> newMap , Map<Id, Case> oldMap ){
        try{
            Integer fieldLength = 255;
			fieldLength = Case.Description_Highlights__c.getDescribe().getLength();            
            for(Case cs : newList){
                if(cs.description != null && cs.description != ''){
	                cs.Description_Highlights__c = cs.description.length() > fieldLength ? cs.description.substring(0,fieldLength) : cs.description;
                }else{
                    cs.Description_Highlights__c = null;
                }
                if (Trigger.isInsert) {
                    cs.Status_Last_Modified_Date__c = Date.today();
                } else if (Trigger.isUpdate) {
                    Case oldCase = oldMap.get(cs.Id);
                    if (cs.Status != oldCase.Status) {
                        cs.Status_Last_Modified_Date__c = Date.today();
                    }
                }


            }
        }catch(exception e){
            System.debug(e.getMessage());
        }        
    }
    
}