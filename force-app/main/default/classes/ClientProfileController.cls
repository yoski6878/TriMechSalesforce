public without sharing class ClientProfileController {

    @AuraEnabled
    public static ClientProfileSection[] getQuestionsForAccount(String recordId){
        
        Map<String,Client_Profile_Question__c[]> sectionToQuestions = new Map<String,Client_Profile_Question__c[]>();
        for(Client_Profile_Question__c cpq : [SELECT Id,
                                                  Answer__c,
                                                  Question__c,
                                                  Question_Template__c,
                                                  Question_Template__r.Instructions__c,
                                              	  Question_Template__r.Picklist_Values__c, 
                                                  Question_Type__c,
                                                  Section_Label__c
                                          FROM Client_Profile_Question__c
                                          WHERE Account__c = :recordId
                                          ORDER BY Section_Sort_Order__c ASC, Question_Sort_Order__c DESC]){
        	
        	Client_Profile_Question__c[] questionsForThisSection = new Client_Profile_Question__c[]{cpq};
            if(sectionToQuestions.containsKey(cpq.Section_Label__c)) questionsForThisSection.addAll(sectionToQuestions.get(cpq.Section_Label__c));
            sectionToQuestions.put(cpq.Section_Label__c,questionsForThisSection);                                  
    	}
        
        Map<String,Section_Template__c> labelToTemplateMap = new Map<String,Section_Template__c>();
        for(Section_Template__c temp : [SELECT Id, Name, Instructions__c, Sort_Order__c FROM Section_Template__c]){
        	labelToTemplateMap.put(temp.Name,temp);    
        }
        
        ClientProfileSection[] sectionList = new ClientProfileSection[]{};
        for(String sectionName : sectionToQuestions.keySet()){
        	sectionList.add(new ClientProfileSection(sectionName,labelToTemplateMap.get(sectionName),sectionToQuestions.get(sectionName)));	        
        }
        return sectionList;
    }
    
    @AuraEnabled
    public static String saveAnswers(ClientProfileSection[] wrappers){
        
        try{
            
            Client_Profile_Question__c[] questionsToUpdate = new Client_Profile_Question__c[]{};
            
            for(ClientProfileSection section : wrappers){
                for(Client_Profile_Question__c quest : section.questions) {
                    System.debug('quest.Id: ' + quest.Id);
                    questionsToUpdate.add(quest);
                }
            }
            
            if(!questionsToUpdate.isEmpty()) update questionsToUpdate; 
            return 'success';
            
        }catch(Exception e){
            System.debug('ERROR: ' + e.getMessage() + ' ' + e.getLineNumber());
            return 'ERROR: ' + e.getMessage() + ' ' + e.getLineNumber();
        }
    }
    
    @TestVisible
    public class ClientProfileSection{
        
    	@AuraEnabled public String title {get;set;}  
        @AuraEnabled public Section_Template__c temp {get;set;} 
        @AuraEnabled public Client_Profile_Question__c[] questions {get;set;}
        
        public ClientProfileSection(){}
            
        public ClientProfileSection(String sectionTitle, Section_Template__c t, Client_Profile_Question__c[] sectionQuestions){
            this.title = sectionTitle;
            this.temp = t;
            this.questions = new List<Client_Profile_Question__c>(sectionQuestions);
        }
    }
}