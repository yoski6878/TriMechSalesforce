/**
* @File Name : CaseGenerationFormController.cls
* @Description :
* @Author : Yoseph Kinfu
* @Last Modified By :
* @Last Modified On : Novmeber 19, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 4, 2024 |   | Initial Version
**/

public  without sharing class CaseGenerationFormController {
	
    @AuraEnabled
    public static String generateCase(String caseRecord) {
        try {
            Case caseObj = new Case();
            CaseGenerationFormController.caseRecordWrapper caseRecordWrapper = 
                (CaseGenerationFormController.caseRecordWrapper)JSON.deserialize(caseRecord, CaseGenerationFormController.caseRecordWrapper.class);
            
            List<Asset> assets = new List<Asset>();

            if (caseRecordWrapper.serialNumber != null && caseRecordWrapper.serialNumber != '') {
                assets = [
                    SELECT Id, AccountId, SerialNumber 
                    FROM Asset 
                    WHERE SerialNumber = :caseRecordWrapper.serialNumber
                ];
            }

            Asset matchedAsset = null;
            Account matchedAccount = null;

            if (!assets.isEmpty()) {
                if (assets.size() > 1) {
                    Set<Id> accountIds = new Set<Id>();
                    for (Asset asset : assets) {
                        if (asset.AccountId != null) {
                            accountIds.add(asset.AccountId);
                        }
                    }
                    // Fetch accounts matching asset accounts and user inputs
                    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id IN :accountIds AND Name = :caseRecordWrapper.CompanyName];
                    // Assign the first matched asset with its account
                    if (!accounts.isEmpty()) {
                        matchedAccount = accounts[0];
                        for (Asset ast : assets) {
                            if (ast.AccountId == matchedAccount.Id) {
                                matchedAsset = ast;
                                break;
                            }
                        }
                    } else {
                        accounts = [SELECT Id, Name FROM Account WHERE Id IN :accountIds LIMIT 1];
                        matchedAccount = accounts[0];
                        for (Asset ast : assets) {
                            if (ast.AccountId == matchedAccount.Id) {
                                matchedAsset = ast;
                                break;
                            }
                        }
                    }
                } else {
                    matchedAsset = assets[0];
                    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id = :matchedAsset.AccountId];
                    matchedAccount = accounts[0];
                }
            }

            // Handle case when no asset matches
            if (matchedAsset == null) {
                caseObj.Serial_number_Incorrect__c = true;
            } else {
                caseObj.AccountId = matchedAsset.AccountId;
                caseObj.AssetId = matchedAsset.Id;
            }

            List<Contact> contacts = new List<Contact>();

            if (matchedAccount != null) {
                contacts = [
                    SELECT Id, FirstName, LastName, Phone, Email, AccountId 
                    FROM Contact 
                    WHERE AccountId = :matchedAccount.Id AND Email = :caseRecordWrapper.email
                ];
            } else {
                contacts = [
                    SELECT Id, FirstName, LastName, Phone, Email, AccountId 
                    FROM Contact 
                    WHERE Email = :caseRecordWrapper.email 
                ];
            }

            Contact matchedContact = contacts.isEmpty() ? null : contacts[0];

            if (matchedContact == null) {
                Contact newContact = new Contact();
                newContact.FirstName = caseRecordWrapper.FirstName;
                newContact.LastName = caseRecordWrapper.LastName;
                newContact.Phone = caseRecordWrapper.phoneNumber;
                newContact.Email = caseRecordWrapper.email;

                if (matchedAccount != null) {
                    newContact.AccountId = matchedAccount.Id;
                } else {
                    List<Account> accList = [SELECT Id FROM Account WHERE Name = :caseRecordWrapper.CompanyName LIMIT 1];
                    if (!accList.isEmpty()) {
                        newContact.AccountId = accList[0].Id;
                    } else {
                        Account newAccount = new Account(Name = caseRecordWrapper.CompanyName);
                        insert newAccount;
                        newContact.AccountId = newAccount.Id;
                    }
                }
                insert newContact;
                matchedContact = newContact;
            }
            caseObj.ContactId = matchedContact.Id;
            if (caseObj.accountId == null) {
                caseObj.accountId = matchedContact.accountId;
            }

           if (caseRecordWrapper.productName == '3D Printers') {
                // Assign to Hardware queue
                List<Group> hardwareQueue = [
                    SELECT Id 
                    FROM Group 
                    WHERE DeveloperName = 'Hardware_Team_Support' LIMIT 1
                ];
                if (!hardwareQueue.isEmpty()) {
                    caseObj.OwnerId = hardwareQueue[0].Id;
                }
            } else {
                // Assign to Application/Enterprise queue
                List<Group> applicationQueue = [
                    SELECT Id 
                    FROM Group 
                    WHERE DeveloperName = 'Applications_Enterprise_Support' LIMIT 1
                ];
                if (!applicationQueue.isEmpty()) {
                    caseObj.OwnerId = applicationQueue[0].Id;
                }
            }

            // Fallback to Unassigned_Cases queue if OwnerId is still not set
            if (caseObj.OwnerId == null) {
                List<Group> fallbackQueue = [
                    SELECT Id 
                    FROM Group 
                    WHERE DeveloperName = 'Unassigned_Cases' LIMIT 1
                ];
                if (!fallbackQueue.isEmpty()) {
                    caseObj.OwnerId = fallbackQueue[0].Id;
                }
            }

            // Populate case details
            caseObj.Product_Name__c = caseRecordWrapper.productName;
            caseObj.Issue__c = caseRecordWrapper.productName;
            caseObj.Subject = caseRecordWrapper.subject;
            caseObj.Priority = caseRecordWrapper.priority;
            caseObj.Description = caseRecordWrapper.description;
            caseObj.Software_Version__c = caseRecordWrapper.softwareVersion;
            caseObj.Serial_Number__c = caseRecordWrapper.serialNumber;
            caseObj.Guest_User_FileUpload__c = caseRecordWrapper.encryptionToken;
            caseObj.ContentVersionId__c = caseRecordWrapper.contentVersionId;
            caseObj.Origin = 'Web Form';
            caseObj.Status = 'New';
            caseObj.SuppliedEmail = caseRecordWrapper.email;
            
            Database.insert(caseObj);

            if (matchedAsset == null) {
            }

            return 'Success';

        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getCustomPickListValues(String objectApiName, String fieldApiName) {
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        try {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjectType == null) {
                throw new IllegalArgumentException('Invalid object API name: ' + objectApiName);
            }
            Schema.SObjectField sObjectField = sObjectType.getDescribe().fields.getMap().get(fieldApiName);
            if (sObjectField == null) {
                throw new IllegalArgumentException('Invalid field API name: ' + fieldApiName);
            }
            Schema.DescribeFieldResult fieldDescribe = sObjectField.getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.PICKLIST) {
                throw new IllegalArgumentException('Field is not a picklist: ' + fieldApiName);
            }
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                Map<String, String> valueMap = new Map<String, String>();
                valueMap.put('label', entry.getLabel());
                valueMap.put('value', entry.getValue());
                picklistValues.add(valueMap);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error retrieving picklist values: ' + ex.getMessage());
        }
        return picklistValues;
    }

    public class caseRecordWrapper
    {
        @AuraEnabled public String FirstName {get;set;}
        @AuraEnabled public String LastName {get;set;}
        @AuraEnabled public String CompanyName {get;set;}
        @AuraEnabled public String phoneNumber {get;set;}
        @AuraEnabled public String email {get;set;}
        @AuraEnabled public String productName {get;set;}
        @AuraEnabled public String softwareVersion {get;set;}
        @AuraEnabled public String serialNumber {get;set;}
        @AuraEnabled public string subject {get;set;}
        @AuraEnabled public String priority {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public String contentDocumentId {get;set;}
        @AuraEnabled public String contentVersionId {get;set;}
        @AuraEnabled public String encryptionToken {get;set;}
    }

}