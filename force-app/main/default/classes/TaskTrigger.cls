public class TaskTrigger {

  public static void beforeInsert(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
      for(Task t : newList){
            if(t.Type == 'Form Submission' && t.IsClosed == false) t.Status = 'Completed';
        }
    
  }
    
  /*public static void beforeUpdate(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
            
  }
    
    public static void beforeDelete(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
          
  }*/
    
  public static void afterInsert(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
    
        Task[] formSubmissionTasks = new Task[]{};
        Set<String> campIds = new Set<String>();
      
        for(Task t : newList){
            System.debug(t);
            if(t.Description != null){
                
                if(t.Type == 'Form Submission' && t.Description.contains('sfCampaignId: ') && t.Description.substringBetween('sfCampaignId: ','\n') != 'null'){
                    System.debug('We got a task!');
                    formSubmissionTasks.add(t);
                    String cIdStr = t.Description.substringBetween('sfCampaignId: ','\n') == null ? 
                        t.Description.substringAfter('sfCampaignId: ') : t.Description.substringBetween('sfCampaignId: ','\n');
                    cIdStr = cIdStr.left(15);
                    campIds.add(cIdStr);
                }
            }
        }
        
        System.debug(campIds);
        if(!formSubmissionTasks.isEmpty()) createLeadAssignmentProcessRecord(formSubmissionTasks,campIds);
  }
  
  /*public static void afterUpdate(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
      
  }
  
  public static void afterDelete(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
        
  }
  
  public static void afterUnDelete(List<Task> newList,List<Task> oldList, Map<Id,Task> newMap, Map<Id,Task> oldMap){
      
  }*/  
    
    public static void createLeadAssignmentProcessRecord(Task[] formSubTasks, Set<String> campaignIds){
        
        Map<Id,Set<Id>> campToProductGroups = new Map<Id,Set<Id>>();
        Map<Id,String[]> groupToProductNames = new Map<Id,String[]>();
        for(Campaign_Product__c cp : [SELECT Id, Campaign__c, Product__r.Product_Group__c, Product__r.Name FROM Campaign_Product__c WHERE Product__r.Product_Group__c != null AND Campaign__c IN :campaignIds]){
            
            Set<Id> prodGrpIdsForThisCamp = new Set<Id>{cp.Product__r.Product_Group__c};     
            if(campToProductGroups.containsKey(cp.Campaign__c)) prodGrpIdsForThisCamp.addAll(campToProductGroups.get(cp.Campaign__c));
            campToProductGroups.put(cp.Campaign__c,prodGrpIdsForThisCamp);
            
            String[] prodNamesForThisGroup = new String[]{cp.Product__r.Name};
            if(groupToProductNames.containsKey(cp.Product__r.Product_Group__c)) prodNamesForThisGroup.addAll(groupToProductNames.get(cp.Product__r.Product_Group__c));
            groupToProductNames.put(cp.Product__r.Product_Group__c,prodNamesForThisGroup);
        }
        
        Map<Id,String> groupIdToProdString = new Map<Id,String>();
        for(Id groupId : groupToProductNames.keySet()){
            
            Set<String> prodNameSet = new Set<String>(groupToProductNames.get(groupId));
            String prodString = '';
            for(String pName : prodNameSet){
                prodString += pName + '; ';
            }
            if(prodString.endsWith('; ')) prodString = prodString.substringBeforeLast(';');
            groupIdToProdString.put(groupId,prodString);
        }
        
        Lead_Assignment_Process__c[] newLeadAssignmentProcessRecord = new  Lead_Assignment_Process__c[]{};
        for(Task t : formSubTasks){
            if(t.Description != null){
            
                String campaignId = null;
                String accountId = null;
                String contactId = null;
                String campaignname = null; 
                String vendorname = 'TriMech'; 
                String sourcetype = 'Form Submission';
                
                
                /*String utmSource = '';
                String utmCampaign = '';
                String utmMedium = '';
                String utmTerm = '';
                String utmContent = ''; */
                
                if(t.WhoId != null){
                    if(String.valueOf(t.WhoId).startsWith('003')) contactId = t.WhoId;
                }
                
                if(t.AccountId != null) accountId = t.AccountId;
                
                //Related To
                if(t.Description.contains('sfCampaignId: ')) campaignId = t.Description.substringBetween('sfCampaignId: ','\n') == null ? t.Description.substringAfter('sfCampaignId: ') : t.Description.substringBetween('sfCampaignId: ','\n');
                campaignId = campaignId.left(15);
                if(t.Description.contains('Campaign Name: ')) campaignname = t.Description.substringBetween('Campaign Name: ','\n') == null ? t.Description.substringAfter('Campaign Name: ') : t.Description.substringBetween('Campaign Name: ','\n');
                if(t.Description.contains('Vendor: ')) vendorname = t.Description.substringBetween('Vendor: ','\n') == null ? t.Description.substringAfter('Vendor: ') : t.Description.substringBetween('Vendor: ','\n');
                if(t.Description.contains('Source Type: ')) sourcetype = t.Description.substringBetween('Source Type: ','\n') == null ? t.Description.substringAfter('Source Type: ') : t.Description.substringBetween('Source Type: ','\n');
                /*if(t.Description.contains('utm_source: ')) utmSource = t.Description.substringBetween('utm_source: ','\n') == null ? t.Description.substringAfter('utm_source: ') : t.Description.substringBetween('utm_source: ','\n');
                if(t.Description.contains('utm_campaign: ')) utmCampaign = t.Description.substringBetween('utm_campaign: ','\n') == null ? t.Description.substringAfter('utm_campaign: ') : t.Description.substringBetween('utm_campaign: ','\n');
                if(t.Description.contains('utm_medium: ')) utmMedium = t.Description.substringBetween('utm_medium: ','\n') == null ? t.Description.substringAfter('utm_medium: ') : t.Description.substringBetween('utm_medium: ','\n');
                if(t.Description.contains('utm_term: ')) utmTerm = t.Description.substringBetween('utm_term: ','\n') == null ? t.Description.substringAfter('utm_term: ') : t.Description.substringBetween('utm_term: ','\n');
                if(t.Description.contains('utm_content: ')) utmContent = t.Description.substringBetween('utm_content: ','\n') == null ? t.Description.substringAfter('utm_content: ') : t.Description.substringBetween('utm_content: ','\n');
                */
                
                if(campaignId != null){
                    if(campToProductGroups.containsKey(campaignId)){
                        for(Id prodGrpId : campToProductGroups.get(campaignId)){
                            newLeadAssignmentProcessRecord.add(new Lead_Assignment_Process__c(Task_ID__c = t.Id, Submission_Details__c = t.Subject + '\n\n' + t.Description, Campaign_Name__c = campaignname, Vendor__c = vendorname, Source_Type__c = sourcetype, Campaign__c = campaignId, Account__c = accountId, Contact__c = contactId, Product_Group__c = prodGrpId, Product_Interest__c = groupIdToProdString.containsKey(prodGrpId) ?  groupIdToProdString.get(prodGrpId) : null));        
                        }   
                    }
                }
            }
        }
        
        //if(!newLeadAssignmentProcessRecord.isEmpty()) insert newLeadAssignmentProcessRecord;
        if(!newLeadAssignmentProcessRecord.isEmpty()) {
            InsertLeadAssignmentProcessQueueable q = new InsertLeadAssignmentProcessQueueable(newLeadAssignmentProcessRecord);
            System.enqueueJob(q);        
        }
    }
}