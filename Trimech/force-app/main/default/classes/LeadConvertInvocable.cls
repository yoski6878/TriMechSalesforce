public with sharing class LeadConvertInvocable {

    //public static final List<String> stageNames = new List<String>{'New', 'Neglected', 'In Progress', 'Dormant'};

    @InvocableMethod(label='Batch Convert Leads' description='A method for converting leads into existing accounts and opportunities if they exist. Batched to avoid Apex governor limits')
    public static List<InvocationResponse> batchConvertLeads(List<InvocationRequest> requests) {
        List<InvocationResponse> responses = new List<InvocationResponse>();
        Map<Integer, List<Lead>> reqCountLeadListMap = new Map<Integer, List<Lead>>();
        Map<Integer, Integer> reqCountBatchSizeMap = new Map<Integer, Integer>();
        //Map<Integer, InvocationRequest> batchSizeToRequestMap = new Map<Integer, InvocationRequest>();
        Map<Integer, InvocationRequest> reqCountToRequestMap = new Map<Integer, InvocationRequest>();
        Map<InvocationRequest, ID> requestToBatchIdMap = new Map<InvocationRequest, ID>();

        System.debug('LeadConvertInvocable.batchConvertLeads() num requests: ' + requests.size());
        

        //try {
            Integer reqCount = 0;
            for (InvocationRequest req : requests) {
                InvocationResponse resp = new InvocationResponse();
                resp.originalRequest = req;
                resp.flowInterviewId = req.flowInterviewId;
                Set<String> passedLeadIds = new Set<String>();
                List<Lead> leads = new List<Lead>();

                for(Lead ld : req.leadList) {
                    passedLeadIds.add(ld.id);
                }

                if (passedLeadIds.size()==0) {
                    resp.leadBatched = false;
                    resp.errorMessage = 'No Leads passed!';
                } else {
                    System.debug('LeadConvertInvocable.batchConvertLeads() passedLeadIds size: ' + passedLeadIds.size());
                    leads = [SELECT id, Company, Street, City, State, PostalCode, Country, Lead_Product_Category__c, Campaign_Type__c, Lead_Sales_Rep_to_Assign__c, Training_Course_Date__c, Training_Course_Location__c, Training_Course_Name__c, pi__campaign__c, Last_Registered_Event__c, Last_Attended_Trade_Show__c, LSC_Campaign__c, LeadSource, Lead_Product_of_Interest__c, pi__comments__c, GCLID_Google_Click_Identification__c FROM Lead WHERE id in: passedLeadIds];
                    for (Lead ld : leads) {
                        System.debug('LeadConvertInvocable.batchConvertLeads() lead id: ' + ld.id);
                        System.debug('LeadConvertInvocable.batchConvertLeads() ld.company: ' + ld.Company);
                        System.debug('LeadConvertInvocable.batchConvertLeads() ld.PostalCode: ' + ld.PostalCode);
                    }
                    if (leads.size()>0) {
                        requestToBatchIdMap.put(req, null);
                        reqCountLeadListMap.put(reqCount, leads);
                        reqCountBatchSizeMap.put(reqCount, req.batchSize);
                        reqCountToRequestMap.put(reqCount, req);
                        //batchSizeToRequestMap.put(reqCount, req);
                    }
                }
                
                /*if (batchSizeLeadListMap.containsKey(req.batchSize)) {
                    leads = batchSizeLeadListMap.get(req.batchSize);
                }
    
                if (req.leadList == null) {
                    resp.leadBatched = false;
                    resp.errorMessage = 'No Leads passed!';
                } else {
                    System.debug('LeadConvertInvocable.batchConvertLeads() leadList size: ' + req.leadList.size());
                    for (Lead ld : req.leadList) {
                        System.debug('LeadConvertInvocable.batchConvertLeads() lead id: ' + ld.id);
                        System.debug('LeadConvertInvocable.batchConvertLeads() ld.company: ' + ld.Company);
                        System.debug('LeadConvertInvocable.batchConvertLeads() ld.PostalCode: ' + ld.PostalCode);
                        if (ld != null) {
                            leads.add(ld);
                            requestToBatchIdMap.put(req, null);
                        }
                    }
                }

                if (leads.size()>0) {
                    batchSizeLeadListMap.put(req.batchSize, leads);
                    batchSizeToRequestMap.put(req.batchSize, req);
                }*/

                responses.add(resp); 
                reqCount++;
            }
    
            for (Integer rCount : reqCountLeadListMap.keySet()) {
                List<Lead> leads = reqCountLeadListMap.get(rCount);
                LeadConvertBatchable lcBatchable = new LeadConvertBatchable(leads);
                ID batchId = Database.executeBatch(lcBatchable, reqCountBatchSizeMap.get(rCount));
                requestToBatchIdMap.put(reqCountToRequestMap.get(rCount), batchId);
            }

            for (InvocationResponse resp : responses) {
                if (resp.leadBatched == false) {
                    continue;
                }

                String batchID;

                if (requestToBatchIdMap.containsKey(resp.originalRequest)) {
                    batchID = String.valueOf(requestToBatchIdMap.get(resp.originalRequest));
                    if (batchID == '000000000000000') {
                        resp.leadBatched = false;
                        resp.errorMessage = 'Failed to create batch!';
                        continue;
                    } else {
                        resp.batchId = batchID;
                        resp.leadBatched = true;
                    }
                }
            } 
            
            return responses;
        //} catch (Exception e) {
            //throw new AuraHandledException(e.getMessage());
        //}
    }

    public class InvocationRequest {
        @InvocableVariable
        public String flowInterviewId;

        @InvocableVariable
        public List<Lead> leadList;

        @InvocableVariable
        public Integer batchSize;
    }

    public class InvocationResponse {
        @InvocableVariable
        public String flowInterviewId;

        @InvocableVariable
        public Boolean leadBatched;

        @InvocableVariable
        public String batchId;

        @InvocableVariable
        public String errorMessage;

        @InvocableVariable
        public InvocationRequest originalRequest;
    }
}