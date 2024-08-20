@isTest
private class ClientProfileController_UnitTests {

    @isTest
    private static void testController(){
        
        Section_Template__c t1 = new Section_Template__c(Name = 'First Section', Sort_Order__c = 1);
        Section_Template__c t2 = new Section_Template__c(Name = 'Second Section', Sort_Order__c = 2);
        insert new Section_Template__c[]{t1,t2};
            
        Question_Template__c qt1 = new Question_Template__c(Section_Template__c = t1.Id, Question__c = 'Need APEX development?', Active__c = true, Type__c = 'Picklist', Sort_Order__c = 1, Picklist_Values__c = 'Yes;No');
        Question_Template__c qt2 = new Question_Template__c(Section_Template__c = t2.Id, Question__c = 'Have you contacted Eustace Consuling?', Active__c = true, Type__c = 'Picklist', Sort_Order__c = 1, Picklist_Values__c = 'Yes;No');
        insert new Question_Template__c[]{qt1,qt2};
        
        Account a = new Account(Name = 'Eustace Consulting', Website = 'www.eustaceconsulting.com');
        insert a;
        
        Client_Profile_Question__c q1 = new Client_Profile_Question__c(Account__c = a.Id, Question_Template__c = qt1.Id, Question__c = qt1.Question__c);
        Client_Profile_Question__c q2 = new Client_Profile_Question__c(Account__c = a.Id, Question_Template__c = qt2.Id, Question__c = qt2.Question__c);
        insert new Client_Profile_Question__c[]{q1,q2};
            
        Test.startTest();
        ClientProfileController.ClientProfileSection[] sections = ClientProfileController.getQuestionsForAccount(String.valueOf(a.Id));
        for(ClientProfileController.ClientProfileSection sec : sections){
            for(Client_Profile_Question__c quest : sec.questions){
                quest.Answer__c = 'Yes';
            }
        }
        String result = ClientProfileController.saveAnswers(sections);
        Test.stopTest();
        
        System.assertEquals('success', result);
    }
    
    @isTest
    private static void testErrorHandle(){
        
        Test.startTest();
        String result = ClientProfileController.saveAnswers(null);
        Test.stopTest();
        
        System.assertNotEquals('success', result);
    }
}