public without sharing class FlowCommunityUserController {

    @AuraEnabled
    public static Map<String, List<PicklistOption>> getPicklists() {
        Map<String, List<PicklistOption>> data = new Map<String, List<PicklistOption>>();

        data.put('TimeZoneSidKey', new List<PicklistOption>());
        for (Schema.PicklistEntry ple : User.TimeZoneSidKey.getDescribe().getPicklistValues()) {
            data.get('TimeZoneSidKey')
                .add(new PicklistOption(ple.getLabel(), ple.getValue()));
        }

        data.put('LocaleSidKey', new List<PicklistOption>());
        for (Schema.PicklistEntry ple : User.LocaleSidKey.getDescribe().getPicklistValues()) {
            data.get('LocaleSidKey')
                .add(new PicklistOption(ple.getLabel(), ple.getValue()));
        }

        data.put('EmailEncodingKey', new List<PicklistOption>());
        for (Schema.PicklistEntry ple : User.EmailEncodingKey.getDescribe().getPicklistValues()) {
            data.get('EmailEncodingKey')
                .add(new PicklistOption(ple.getLabel(), ple.getValue()));
        }

        data.put('LanguageLocaleKey', new List<PicklistOption>());
        for (Schema.PicklistEntry ple : User.LanguageLocaleKey.getDescribe().getPicklistValues()) {
            data.get('LanguageLocaleKey')
                .add(new PicklistOption(ple.getLabel(), ple.getValue()));
        }

        return data;
    }


    @AuraEnabled
    public static Map<String, String> getUserDetails(String contactId,String userId) {
        List<User> usr = new List<User>();
        List<Contact> con = new List<Contact>();

        if (String.isBlank(userId) && String.isBlank(contactId)) {
            return null;
        }else if (String.isNotBlank(userId)) {
            usr = [SELECT FirstName, LastName, Email, Username, Phone, CommunityNickname, Alias, TimeZoneSidKey,  LocaleSidKey, EmailEncodingKey, LanguageLocaleKey, IsActive FROM User WHERE Id = :userId LIMIT 1];
        }else if(String.isNotBlank(contactId)){
            con = [ SELECT FirstName, LastName, Email, Phone FROM Contact WHERE Id = :contactId LIMIT 1];
        }

        if(usr.size() > 0){
            User u = usr[0];
            return new Map<String, String>{
                'objectName' => 'User',
                'FirstName' => u.FirstName ?? '',
                'LastName' => u.LastName ?? '',
                'Email' => u.Email ?? '',
                'Username' => u.Username ?? '',
                'Phone' => u.Phone ?? '',
                'CommunityNickname' => u.CommunityNickname ?? '',
                'Alias' => u.Alias ?? '',
                'TimeZoneSidKey' => u.TimeZoneSidKey ?? '',
                'LocaleSidKey' => u.LocaleSidKey ?? '',
                'EmailEncodingKey' => u.EmailEncodingKey ?? '',
                'LanguageLocaleKey' => u.LanguageLocaleKey ?? '',
                'IsActive' => String.valueOf(u.IsActive)
            };
        }else if (con.size() > 0){
            Contact c = con[0];
            return new Map<String, String>{
                'objectName' => 'Contact',
                'FirstName' => c.FirstName ?? '',
                'LastName' => c.LastName ?? '',
                'Email' => c.Email ?? '',
                'Phone' => c.Phone ?? ''
            }; 
        }else {
            return null;
        }
    }

    @AuraEnabled
    public static String upsertUser(String userJson) {
        if (String.isBlank(userJson)) {
            throw new AuraHandledException('User data is required.');
        }

        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(userJson);

        User u = new User();
        if (String.isNotBlank(String.valueOf(fields.get('Id')))) {
            u.Id = (String) fields.get('Id');
        }

        u.FirstName = (String) fields.get('FirstName');
        u.LastName = (String) fields.get('LastName');
        u.Email = (String) fields.get('Email');
        u.Username = (String) fields.get('Username');
        u.Phone = (String) fields.get('Phone');
        u.CommunityNickname = (String) fields.get('CommunityNickname');
        u.Alias = (String) fields.get('Alias');
        u.TimeZoneSidKey = (String) fields.get('TimeZoneSidKey');
        u.LocaleSidKey = (String) fields.get('LocaleSidKey');
        u.EmailEncodingKey = (String) fields.get('EmailEncodingKey');
        u.LanguageLocaleKey = (String) fields.get('LanguageLocaleKey');
        u.ProfileId = (String) fields.get('ProfileId');
        u.ContactId = (String) fields.get('ContactId');
        u.IsActive = Boolean.valueOf(fields.get('IsActive'));
        try {
            if(u.Id == null ){
                insert u;
            }else {
                update u;
            }
            return u.Id;
        } catch (DmlException e) {
            // Return the first meaningful error message only
            String errorMsg = e.getDmlMessage(0);
            if (String.isBlank(errorMsg)) {
                errorMsg = e.getMessage();
            }
            System.debug('e.getMessage()--->'+e.getMessage());
            throw new AuraHandledException(errorMsg);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}