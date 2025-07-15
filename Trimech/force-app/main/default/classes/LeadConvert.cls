public with sharing class LeadConvert {
    public static final ID OPPORTUNITY_LEAD_RECORD_TYPE_ID = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Lead').getRecordTypeId();
    public static final LeadStatus LEAD_STATUS_CONVERT = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
    public static final List<String> OPPORTUNITY_STAGE_NAMES = new List<String>{'New', 'Neglected', 'In Progress', 'Dormant'};
    public static final String ACCOUNT_SUBSIDIARY_ENTERPRISE = System.Label.Enterprise_Subsidiary;

    public static List<Id> convertLeads(List<Lead> leads) {
        Map<ID, Opportunity> existingOpps = new Map<ID,Opportunity>();
        Set<String> leadCompanyNames = getLeadCompanyNames(leads);
        Map<ID, Lead> leadMap = new Map<ID, Lead>();
        Map<String, Account> accountsByKey = getAccountsByKey(leadCompanyNames);
        List<Database.LeadConvert> leadsToConvert = new List<Database.LeadConvert>();
        Map<ID, ID> leadIdOppIdMap = new Map<ID, ID>();
        System.debug('LeadConvert.convertLeads() size fof leads: ' + leads.size());
        
        for (Lead l : leads) {
            leadMap.put(l.id, l);
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(l.Id);
            lc.setConvertedStatus(LEAD_STATUS_CONVERT.MasterLabel);
            System.debug('LeadConvert.convertLeads() l.id: ' + l.id);
            System.debug('LeadConvert.convertLeads() l.company: ' + l.Company);
            System.debug('LeadConvert.convertLeads() l.PostalCode: ' + l.PostalCode);
            String cleanedZip = getCleanedZip(l.Country, l.PostalCode);
            String key = l.Company.toLowerCase() + cleanedZip;
            if (accountsByKey.containsKey(key)) {
                Account a = accountsByKey.get(key);
                lc.setAccountId(a.Id);
                if (!a.Opportunities.isEmpty()) {
                    for (Opportunity opp : a.Opportunities) {
                        if (opp.Lead_Product_Category_on_Opp__c == l.Lead_Product_Category__c && l.Lead_Product_Category__c != 'Training Course') {
                            lc.setOpportunityId(opp.Id);
                            existingOpps.put(opp.Id,opp);
                        }
                    }
                }               
            }
            if ((String.isEmpty(l.Campaign_Type__c) == FALSE) && l.Campaign_Type__c != 'UQL') {
                if (lc.getOpportunityId() == null) {
                    String oppName = 'Lead - ' + l.Company + ' - ' + l.Lead_Product_Category__c + ' - ' + Datetime.now().format('MMM d, YY');
                    lc.setOpportunityName(oppName?.left(120));
                
                }
            } else {
                lc.setOpportunityId(null);
                lc.setDoNotCreateOpportunity(true);
            }
            leadsToConvert.add(lc);
        } 

        Map<Id,Opportunity> oppsTouchCount = new Map<Id, Opportunity>([SELECT Id, Touch_Count__c FROM Opportunity WHERE Id IN :existingOpps.keySet()]);
        List<Database.LeadConvertResult> lcrs = Database.convertLead(leadsToConvert);
        List<Opportunity> oppUpdates = new List<Opportunity>();
        Map<ID, Opportunity> oppIdUpdateMap = new Map<ID, Opportunity>();
        List<Id> oppIds = new List<ID>();
        List<Id> contactIds = new List<Id>();
        Map<ID, Account> accIdUpdateMap = new Map<ID, Account>();
        
        Set<Id> uqlContacts = New Set<Id>();
        for (Database.LeadConvertResult lcr : lcrs) {
            ID leadId = lcr.getLeadId();
            ID oppId = lcr.getOpportunityId();
            ID accId = lcr.getAccountId();
            Id contactId = lcr.getContactId();
            contactIds.add(contactId);
            if (oppId == null && contactId != null) {
                uqlContacts.add(contactId);
            }

            if (lcr.isSuccess()) {
                Lead lead = leadMap.get(leadId);
                if (oppId != null) {
                    leadIdOppIdMap.put(leadId, oppId);
                    
                    Opportunity opp = getOpp(lead, oppId, existingOpps, OPPORTUNITY_LEAD_RECORD_TYPE_ID, oppsTouchCount);            
                    if (opp.Id != null && !oppIdUpdateMap.containsKey(opp.Id)) {
                        oppIdUpdateMap.put(opp.Id, opp);
                    }
                }

                if (accId != null) {
                    String key = lead.Company.toLowerCase() + lead.PostalCode;
                    
                    Account acc = new Account(Id = accId);
                    if (!accountsByKey.containsKey(key)) {
                        acc.ShippingStreet = lead.Street;
                        acc.ShippingCity = lead.City;
                        acc.ShippingState = lead.State;
                        acc.ShippingPostalCode = lead.PostalCode;
                        acc.ShippingCountry = lead.Country;
                        if (lead.Lead_Product_Category__c == 'Enterprise') {
                            acc.Subsidiary__c = ACCOUNT_SUBSIDIARY_ENTERPRISE;
                        }
                    }
                    
                    if (!accIdUpdateMap.containsKey(accId)) {
                        accIdUpdateMap.put(accId, acc);
                    }
                }
            }

            // Add oppId to list even if null so returned list matches size of input
            oppIds.add(oppId);
        }

        List<Contact> conList = [SELECT Id, MQL_SQL__c, UQL_Count__c FROM Contact WHERE Id IN :contactIds];
        List<Contact> consToUpdate = new List<Contact>();
        
        for (Contact con : conList) {
            if(uqlContacts.contains(con.id)) {
                con.UQL_Count__c = 1;
            } else {
                con.MQL_SQL__c = 1;
            }
            consToUpdate.add(con);
        }

        if (!oppIdUpdateMap.isEmpty()) {
            update oppIdUpdateMap.values();
        }

        if (!accIdUpdateMap.isEmpty()) {
            update accIdUpdateMap.values();
        }

        if (!consToUpdate.isEmpty()) {
            update consToUpdate;
        }
        
        return oppIds;
    }
    
    public static Opportunity getOpp(Lead l, ID opportunityId, Map<Id,Opportunity> existingOpps, String leadRecordTypeId, Map<Id,Opportunity> oppsTouchCount) {
        Opportunity opp = new Opportunity();

        if (existingOpps.containsKey(opportunityId)) {
            /*Update Stage to “New”
            Append Lead Product of Interest with new values from Lead
            Set Sales Rep to Assign with value from Lead*/
            Opportunity existingOpp = existingOpps.get(opportunityId);
            opp.Id = opportunityId;
            opp.Lead_Sales_Rep_to_Assign__c = l.Lead_Sales_Rep_to_Assign__c;
            opp.StageName = 'New';
            opp.Training_Course_Date__c = l.Training_Course_Date__c;
            opp.Training_Course_Location__c = l.Training_Course_Location__c;
            opp.Training_Course_Name__c = l.Training_Course_Name__c;
            opp.Lead_Campaign_Type__c = l.Campaign_Type__c?.left(255);
            opp.Pardot_Campaign__c = l.pi__campaign__c?.left(255);
            opp.Last_Registered_Event__c = l.Last_Registered_Event__c;
            opp.Last_Attended_Trade_Show__c = l.Last_Attended_Trade_Show__c;
            opp.LSC_Campaign__c = l.LSC_Campaign__c?.left(255);
            opp.GCLID_Google_Click_Identification__c = l.GCLID_Google_Click_Identification__c?.left(255);
            opp.Touch_Count__c = oppsTouchCount.get(opportunityId).Touch_Count__c + 1;
            
            List<CampaignMember> campaignMembers = [SELECT Id, Name, CampaignId FROM CampaignMember WHERE LeadId = :l.Id ORDER BY LastModifiedDate DESC LIMIT 1];
            if(campaignMembers.size()>0){
                opp.CampaignId = campaignMembers[0].CampaignId;
            }
            
            if (existingOpp.LeadSource == '') opp.LeadSource = l.LeadSource;
            if (l.Lead_Product_of_Interest__c != null) {
                Set<String> allOptions = new Set<String>();
                List<String> leadOptions = l.Lead_Product_of_Interest__c.split(';');
                allOptions.addAll(leadOptions);
                if (existingOpp.Lead_Product_of_Interest_on_Opp__c != null) {
                    List<String> oppOptions = existingOpp.Lead_Product_of_Interest_on_Opp__c.split(';');
                    allOptions.addAll(oppOptions);
                }
                List<String> finalOptions = new List<String>();
                finalOptions.addAll(allOptions);
                opp.Lead_Product_of_Interest_on_Opp__c = String.join(finalOptions,';');
            }
            if (l.pi__comments__c != null) {
                if (existingOpp.Description != null) {
                    opp.Description = existingOpp.Description + '  ' + l.pi__comments__c; 
                } else {
                    opp.Description = l.pi__comments__c; 
                }
            }
        } else {
            //Set close date and record type for new opportunities
            opp.Id = opportunityId;
            opp.CloseDate = Date.today().addDays(30);
            opp.RecordTypeId = leadRecordTypeId;
            opp.Description = l.pi__comments__c;
            opp.Touch_Count__c = 1;
        }

        return opp;
    }

    public static Map<String,Account> getAccountsByKey(Set<String> leadCompanyNames) {
        List<Account> existingAccounts = [
            SELECT      Id,
                        Name,
                        LastActivityDate,
                        Subsidiary__c,
                        BillingStreet,
                        BillingCity,
                        BillingState,
                        BillingPostalCode,
                        BillingCountry,
                        ShippingStreet,
                        ShippingCity,
                        ShippingState,
                        ShippingPostalCode,
                        ShippingCountry,
                        (
                            SELECT  Id,
                                    Name,
                                    Lead_Product_Category_on_Opp__c,
                                    Lead_Product_of_Interest_on_Opp__c,
                                    Lead_Sales_Rep_to_Assign__c,
                                    StageName,
                                    LeadSource,
                                    Description,
                                    Pardot_Campaign__c,
                                    LSC_Campaign__c,
                                    GCLID_Google_Click_Identification__c,
                                    CampaignId
                            FROM    Opportunities 
                            WHERE   StageName IN :OPPORTUNITY_STAGE_NAMES 
                            AND     RecordTypeId = :OPPORTUNITY_LEAD_RECORD_TYPE_ID
                        ) 
            FROM        Account 
            WHERE       Name IN :leadCompanyNames 
            ORDER BY    LastActivityDate DESC
        ];
        Map<String,Account> accountsByKey = new Map<String,Account>();
        for (Account a : existingAccounts) {
            String key = a.Name.toLowerCase() + getCleanedZip(a.ShippingCountry, a.ShippingPostalCode);
            if (!accountsByKey.containsKey(key)) {
                accountsByKey.put(key,a);
            }
        }
        return accountsByKey;
    }

    public static Set<String> getLeadCompanyNames(List<Lead> leads) {
        Set<String> leadCompanyNames = new Set<String>();
        for (Lead l : leads) {
            if (String.isNotBlank(l.Company)) {
                leadCompanyNames.add(l.Company);
            }
        }
        return leadCompanyNames;
    }
    
    public Static String getCleanedZip(String country, String zip) {
        if (zip == null) {
            return '';
        } else if (zip.length() >=5) {
            if (country != null) {
                if (country.toLowerCase() == 'us' || country.toLowerCase() == 'usa' || country.toLowerCase().contains('united states')) {
                    return zip.substring(0,5);
                } else if (country.toLowerCase() == 'ca' || country.toLowerCase() == 'canada') {
                    return zip.deleteWhitespace();
                } else {
                    return zip.deleteWhitespace();
                }
            } else {
                if (Pattern.matches('\\d{5}(-\\d{1,})?', zip)) { //somewhat matches US zip code format
                    return zip.substring(0,5);
                } else {
                    return zip.deleteWhitespace();
                }
            }            
        } else {
            return zip;
        }
    }
   
}