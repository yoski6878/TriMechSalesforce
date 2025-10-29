public class AddressTriggerHandler {
    
    public static void beforeInsert(List<Schema.Address> newList){
        List<Schema.Location> createLocationList = new List<Schema.Location>();
        Map<Integer, Integer> addressToLocationIndex = new Map<Integer, Integer>();
    
        // Step 1: Create matching Location records
        for (Integer i = 0; i < newList.size(); i++) {
            Schema.Address addr = newList[i];
    
            Schema.Location loc = new Schema.Location();
            loc.Name = 'Auto Generated Location';
            loc.LocationType = addr.LocationType;
    
            addressToLocationIndex.put(i, createLocationList.size());
            createLocationList.add(loc);
        }
    
        // Step 2: Insert Locations
        insert createLocationList;
    
        // Step 3: Assign ParentId to Address records
        for (Integer i = 0; i < newList.size(); i++) {
            Integer locIndex = addressToLocationIndex.get(i);
            newList[i].ParentId = createLocationList[locIndex].Id;
        }
    }

    
    
    public static void afterUpdate(List<Schema.Address> newList, List<Schema.Address> oldList, Map<Id, Schema.Address> newMap, Map<Id, Schema.Address> oldMap) {
        Set<Id> proposalIds = new Set<Id>();
    
        for (Schema.Address addr : newList) {
            if (addr.proposal__c != null) {
                proposalIds.add(addr.proposal__c);
            }
        }
    
        Map<Id, Quote> proposalMap = new Map<Id, Quote>(
            [SELECT Id, IsSyncing,
                     BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                     ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
             FROM Quote
             WHERE Id IN :proposalIds]
        );
    
        // Fetch all related addresses for proposals
        Map<Id, List<Schema.Address>> proposalToAddressesMap = new Map<Id, List<Schema.Address>>();
        
        
        for (Schema.Address addr : [
            SELECT Id, proposal__c, Primary_Billing_Address__c, Primary_Shipping_Address__c
            FROM Address
            WHERE proposal__c IN :proposalIds
        ]) {
            if (!proposalToAddressesMap.containsKey(addr.proposal__c)) {
                proposalToAddressesMap.put(addr.proposal__c, new List<Schema.Address>());
            }
            proposalToAddressesMap.get(addr.proposal__c).add(addr);
        }
    
        List<Quote> updateProposalList = new List<Quote>();
        List<Schema.Address> addressesToUpdate = new List<Schema.Address>();
    
        for (Schema.Address addr : newList) {
            if (addr.proposal__c != null && proposalMap.containsKey(addr.proposal__c)) {
                Quote proposal = proposalMap.get(addr.proposal__c);
                Boolean shouldUpdateProposal = false;
    
                if (addr.Primary_Billing_Address__c == true && addr.street != null) {
                    proposal.BillingStreet       = addr.street;
                    proposal.BillingCity         = addr.city;
                    proposal.BillingState        = addr.state;
                    proposal.BillingPostalCode   = addr.postalCode;
                    proposal.BillingCountry      = addr.country;
                    proposal.BillingLatitude     = addr.latitude;
                    proposal.BillingLongitude    = addr.longitude;
                    shouldUpdateProposal = true;
    
                    // Set other billing addresses' primary flag to false
                    for (Schema.Address related : proposalToAddressesMap.get(addr.proposal__c)) {
                        if (related.Id != addr.Id && related.Primary_Billing_Address__c == true) {
                            related.Primary_Billing_Address__c = false;
                            addressesToUpdate.add(related);
                        }
                    }
                }
    
                if (addr.Primary_Shipping_Address__c == true && addr.street != null) {
                    proposal.ShippingStreet       = addr.street;
                    proposal.ShippingCity         = addr.city;
                    proposal.ShippingState        = addr.state;
                    proposal.ShippingPostalCode   = addr.postalCode;
                    proposal.ShippingCountry      = addr.country;
                    proposal.ShippingLatitude     = addr.latitude;
                    proposal.ShippingLongitude    = addr.longitude;
                    shouldUpdateProposal = true;
    
                    // Set other shipping addresses' primary flag to false
                    for (Schema.Address related : proposalToAddressesMap.get(addr.proposal__c)) {
                        if (related.Id != addr.Id && related.Primary_Shipping_Address__c == true) {
                            related.Primary_Shipping_Address__c = false;
                            addressesToUpdate.add(related);
                        }
                    }
                }
    
                if (shouldUpdateProposal && !updateProposalList.contains(proposal)) {
                    updateProposalList.add(proposal);
                }
            }
        }
    
        if (!updateProposalList.isEmpty()) {
            update updateProposalList;
        }
    
        if (!addressesToUpdate.isEmpty()) {
            update addressesToUpdate;
        }
}

}