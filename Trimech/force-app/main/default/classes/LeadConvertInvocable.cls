public with sharing class LeadConvertInvocable {

    //public static final List<String> stageNames = new List<String>{'New', 'Neglected', 'In Progress', 'Dormant'};


    @InvocableMethod(label='Batch Convert Leads' description='Converts leads in bulk using a single batch job')
	public static List<InvocationResponse> batchConvertLeads(List<InvocationRequest> requests) {
    List<InvocationResponse> responses = new List<InvocationResponse>();
    Set<Id> allLeadIds = new Set<Id>();
    Map<InvocationRequest, Set<Id>> requestToLeadIdsMap = new Map<InvocationRequest, Set<Id>>();

    // Step 1: Collect all lead IDs from all requests
    for (InvocationRequest req : requests) {
        Set<Id> leadIds = new Set<Id>();
        if (req.leadList != null) {
            for (Lead ld : req.leadList) {
                if (ld != null && ld.Id != null) {
                    leadIds.add(ld.Id);
                    allLeadIds.add(ld.Id);
                }
            }
        }
        requestToLeadIdsMap.put(req, leadIds);
    }

    // Step 2: Query all leads in bulk
    Map<Id, Lead> allLeadsMap = new Map<Id, Lead>();
    if (!allLeadIds.isEmpty()) {
        allLeadsMap = new Map<Id, Lead>([
            SELECT Id, Company, PostalCode, Lead_Product_Category__c, Campaign_Type__c, Country,
                Lead_Sales_Rep_to_Assign__c, Training_Course_Date__c, Training_Course_Location__c,
                Training_Course_Name__c, pi__campaign__c, Last_Registered_Event__c,
                Last_Attended_Trade_Show__c, LSC_Campaign__c, LeadSource,
                Lead_Product_of_Interest__c, pi__comments__c, GCLID_Google_Click_Identification__c
            FROM Lead
            WHERE Id IN :allLeadIds
        ]);
    }

    // Step 3: Create final lead list for the single batch job
    List<Lead> combinedLeads = new List<Lead>();
    for (Id leadId : allLeadIds) {
        if (allLeadsMap.containsKey(leadId)) {
            combinedLeads.add(allLeadsMap.get(leadId));
        }
    }

    // Step 4: Create the batch job if leads are found
    String batchId;
    if (!combinedLeads.isEmpty()) {
        // Use batchSize from the first request, or fallback to 25
        Integer batchSize = (requests != null && requests.size() > 0 && requests[0].batchSize != null) ? requests[0].batchSize : 25;

        // Execute a single batch job
        batchId = String.valueOf(Database.executeBatch(new LeadConvertBatchable(combinedLeads), batchSize));
    }

    // Step 5: Prepare response for each request
    for (InvocationRequest req : requests) {
        InvocationResponse resp = new InvocationResponse();
        resp.flowInterviewId = req.flowInterviewId;
        resp.originalRequest = req;

        Set<Id> leadIds = requestToLeadIdsMap.get(req);
        if (leadIds == null || leadIds.isEmpty()) {
            resp.leadBatched = false;
            resp.errorMessage = 'No valid Leads passed!';
        } else if (String.isBlank(batchId) || batchId == '000000000000000') {
            resp.leadBatched = false;
            resp.errorMessage = 'Failed to create batch!';
        } else {
            resp.leadBatched = true;
            resp.batchId = batchId;
        }

        responses.add(resp);
    }

    return responses;
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