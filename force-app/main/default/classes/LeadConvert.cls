public with sharing class LeadConvert {
    public static final ID OPPORTUNITY_LEAD_RECORD_TYPE_ID = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Lead').getRecordTypeId();
    public static final LeadStatus LEAD_STATUS_CONVERT = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
    public static final List<String> OPPORTUNITY_STAGE_NAMES = new List<String>{'New', 'Neglected', 'Dormant'};
    public static final String ACCOUNT_SUBSIDIARY_ENTERPRISE = System.Label.Enterprise_Subsidiary;
    public static final String LPC_DESIGN = System.Label.LPC_Product_Development;
    public static final String SUBSIDIARY_TRI_MECH = 'TriMech Solutions LLC';
    public static final String SUBSIDIARY_JAVELIN = 'Javelin Technologies Inc.';

    // Company names that are placeholder/junk entries — never match an account on these.
    // Derived from production data analysis (Analysis 3, June 2026).
    public static final Set<String> JUNK_COMPANY_NAMES = new Set<String>{
        'individual', 'none', 'n/a', 'na', 'n a', 'self', 'personal', 'personal use',
        'home', 'self employed', 'self-employed', 'student', 'unknown', '[[unknown]]',
        '[not provided]', 'no company', 'myself', 'private', 'retired', 'freelance',
        'consultant', 'independent', 'not applicable', 'other', 'test', 'temp', 'tbd'
    };
    
    // Helper method to determine subsidiary based on country (replicating the flow logic)
    private static String getAccountSubsidiaryByCountry(String shippingCountry) {
        if (shippingCountry != null && shippingCountry != '') {
            String normalizedCountry = shippingCountry.toLowerCase().trim();
            
            // Check for Canada variants - simplified logic based on what's available in Lead object
            if (normalizedCountry == 'canada' || 
                normalizedCountry == 'ca' || 
                normalizedCountry == 'can') {
                return SUBSIDIARY_JAVELIN;
            }
        }
        
        // Default to TriMech Solutions LLC for all other cases (including when country is null/empty)
        return SUBSIDIARY_TRI_MECH;
    }

    // Normalized key identifying "the same brand-new company" within one batch: company name +
    // country + state (all lowercased/trimmed). Used only for intra-batch new-account dedup.
    private static String newCompanyKey(Lead l) {
        String c = String.isBlank(l.Company) ? '' : l.Company.toLowerCase().trim();
        String co = String.isBlank(l.Country) ? '' : l.Country.toLowerCase().trim();
        String st = String.isBlank(l.State) ? '' : l.State.toLowerCase().trim();
        return c + '|' + co + '|' + st;
    }

    // newCompanyKey plus product category, identifying leads that should share ONE new opportunity.
    private static String newCompanyOppKey(Lead l) {
        String product = l.Lead_Product_Category__c == null ? '' : l.Lead_Product_Category__c;
        return newCompanyKey(l) + '|' + product;
    }

    // Translate the Pardot form's raw product (Form_Product__c) into the standard
    // Lead_Product_Category__c / Lead_Product_of_Interest__c values via Pardot_Product_Mapping__mdt.
    // Pardot forms deliver the real product in Form_Product__c while the category/interest arrive as
    // "Not Specified"; without this, opportunity matching, naming and reporting all collapse onto
    // "Not Specified". Done ONCE up front and written back to the DB so the standard Lead->Opportunity
    // field mapping (which reads the committed Lead) also carries the corrected values onto the opp.
    // Leads whose Form_Product__c is blank or has no mapping entry are left untouched.
    private static void applyProductMapping(List<Lead> leads) {
        Map<String, Pardot_Product_Mapping__mdt> mappingByFormValue = new Map<String, Pardot_Product_Mapping__mdt>();
        for (Pardot_Product_Mapping__mdt m : Pardot_Product_Mapping__mdt.getAll().values()) {
            if (String.isNotBlank(m.Form_Product_Value__c)) {
                mappingByFormValue.put(m.Form_Product_Value__c.toLowerCase().trim(), m);
            }
        }
        if (mappingByFormValue.isEmpty()) {
            return;
        }
        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead l : leads) {
            if (String.isBlank(l.Form_Product__c)) {
                continue;
            }
            // Respect an explicitly submitted Lead Product Category: when the lead arrives with a
            // real category value (anything other than null or "Not Specified"), trust it and skip
            // the Form_Product -> mdt remap. This mirrors the matching guard in the
            // Pardot_Contact_Multi_Touch flow so the Apex and flow paths agree: the category
            // "trumps everything" except when it is null/Not Specified, in which case the
            // Form_Product mapping fills it in.
            if (String.isNotBlank(l.Lead_Product_Category__c)
                    && l.Lead_Product_Category__c != 'Not Specified') {
                continue;
            }
            Pardot_Product_Mapping__mdt m = mappingByFormValue.get(l.Form_Product__c.toLowerCase().trim());
            if (m == null) {
                continue;
            }
            Boolean changed = false;
            if (String.isNotBlank(m.Lead_Product_Category__c) && l.Lead_Product_Category__c != m.Lead_Product_Category__c) {
                l.Lead_Product_Category__c = m.Lead_Product_Category__c;
                changed = true;
            }
            if (String.isNotBlank(m.Lead_Product_of_Interest__c) && l.Lead_Product_of_Interest__c != m.Lead_Product_of_Interest__c) {
                l.Lead_Product_of_Interest__c = m.Lead_Product_of_Interest__c;
                changed = true;
            }
            if (changed) {
                leadsToUpdate.add(l);
            }
        }
        if (!leadsToUpdate.isEmpty()) {
            // Partial-success write-back: a single bad Lead (a validation rule, or a mapped value
            // that isn't a valid restricted-picklist entry) must NOT roll back the whole batch's
            // mapping -- otherwise every lead in the batch silently falls back to its raw value and
            // the opp name/category diverge (the production "Not Specified" symptom). With
            // allOrNone=false only the offending lead is left unmapped; the rest persist. Failures
            // are logged per-record (mirrors the convertLead result handling below).
            Database.SaveResult[] writeBackResults = Database.update(leadsToUpdate, false);
            for (Integer i = 0; i < writeBackResults.size(); i++) {
                if (!writeBackResults[i].isSuccess()) {
                    String errMsgs = '';
                    for (Database.Error err : writeBackResults[i].getErrors()) {
                        errMsgs += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    System.debug(LoggingLevel.ERROR, 'Pardot product mapping write-back failed for Lead '
                        + leadsToUpdate[i].Id + ' -> ' + errMsgs);
                }
            }
        }
    }

    public static List<Id> convertLeads(List<Lead> leads) {
        // Normalize Form_Product__c -> Lead_Product_Category__c / Lead_Product_of_Interest__c BEFORE
        // any matching, naming or conversion runs, so every downstream decision uses the real product.
        applyProductMapping(leads);
        Map<ID, Opportunity> existingOpps = new Map<ID,Opportunity>();
        Set<String> leadCompanyNames = getLeadCompanyNames(leads);
        Map<ID, Lead> leadMap = new Map<ID, Lead>();
        Map<String, Account> accountsByKey = getAccountsByKey(leadCompanyNames);
        List<Database.LeadConvert> leadsToConvert = new List<Database.LeadConvert>();

        // --- Email-first account lookup ------------------------------------------------
        // If a Contact with this email already exists on exactly one Account, use that
        // Account directly — bypassing company name + zip matching entirely.
        // Emails found on 2+ accounts are treated as ambiguous and skipped (fall through
        // to name+zip so the safer, more specific match wins).
        Set<String> inboundEmails = new Set<String>();
        for (Lead l : leads) {
            if (String.isNotBlank(l.Email)) inboundEmails.add(l.Email.toLowerCase());
        }
        Map<String, Id> emailFirstAccountId = new Map<String, Id>();
        Set<String> ambiguousEmails = new Set<String>();
        if (!inboundEmails.isEmpty()) {
            for (Contact c : [
                SELECT Email, AccountId
                FROM   Contact
                WHERE  Email IN :inboundEmails
                AND    AccountId != null
            ]) {
                String ek = c.Email.toLowerCase();
                if (ambiguousEmails.contains(ek)) continue;
                if (emailFirstAccountId.containsKey(ek)) {
                    emailFirstAccountId.remove(ek);
                    ambiguousEmails.add(ek);
                } else {
                    emailFirstAccountId.put(ek, c.AccountId);
                }
            }
        }
        Map<Id, Account> accountsById = new Map<Id, Account>();
        // Name-only fallback for leads with no zip. Junk names excluded upstream by getLeadCompanyNames().
        Map<String, Account> accountsByNameOnly = new Map<String, Account>();
        for (Account a : accountsByKey.values()) {
            accountsById.put(a.Id, a);
            String nameKey = a.Name.toLowerCase().trim();
            Account existing = accountsByNameOnly.get(nameKey);
            if (existing == null ||
                (a.LastActivityDate != null && (existing.LastActivityDate == null || a.LastActivityDate > existing.LastActivityDate))) {
                accountsByNameOnly.put(nameKey, a);
            }
        }
        Set<Id> preExistingAccountIds = new Set<Id>(accountsById.keySet());
        preExistingAccountIds.addAll(emailFirstAccountId.values());
        // Load opportunities for email-first accounts not already covered by the name+zip query.
        Set<Id> emailFirstOnlyIds = new Set<Id>(emailFirstAccountId.values());
        emailFirstOnlyIds.removeAll(accountsById.keySet());
        if (!emailFirstOnlyIds.isEmpty()) {
            for (Account a : [
                SELECT Id, Name,
                    (SELECT  Id, Name, Lead_Product_Category_on_Opp__c, LeadSource,
                            Lead_Sales_Rep_to_Assign__c, StageName, Lead_Product_of_Interest_on_Opp__c,
                            Description, Pardot_Campaign__c, LSC_Campaign__c, CampaignId,
                            GCLID_Google_Click_Identification__c, Google_Analytics_Campaign__c,
                            Google_Analytics_Medium__c, Google_Analytics_Referrer__c, Google_Analytics_Source__c,
                            Google_Analytics_Term__c, NDA__c, TD_Lead_Score__c, TD_Lead_Notes__c
                     FROM Opportunities
                     WHERE StageName IN :OPPORTUNITY_STAGE_NAMES
                     AND   RecordTypeId = :OPPORTUNITY_LEAD_RECORD_TYPE_ID
                     ORDER BY LastModifiedDate DESC)
                FROM Account
                WHERE Id IN :emailFirstOnlyIds
            ]) {
                accountsById.put(a.Id, a);
            }
        }
        // -------------------------------------------------------------------------------

        // 1. Collect all unique, non-blank pi__campaign__c values
        Set<String> campaignNames = new Set<String>();
        for (Lead l : leads) {
            leadMap.put(l.id, l);
            if (String.isNotBlank(l.pi__campaign__c)) {
                campaignNames.add(l.pi__campaign__c.trim());
            }
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(l.Id);
            lc.setConvertedStatus(LEAD_STATUS_CONVERT.MasterLabel);
            // Match order: 1) email-first  2) company name + zip  3) company name only (no-zip fallback)
            Account matchedAccount = null;
            String emailKey = String.isNotBlank(l.Email) ? l.Email.toLowerCase() : null;
            if (emailKey != null && emailFirstAccountId.containsKey(emailKey)) {
                Id acctId = emailFirstAccountId.get(emailKey);
                lc.setAccountId(acctId);
                matchedAccount = accountsById.get(acctId);
            }
            if (lc.getAccountId() == null && String.isNotBlank(l.Company)) {
                String nameKey = l.Company.toLowerCase().trim();
                String cleanedZip = getCleanedZip(l.Country, l.PostalCode);
                if (accountsByKey.containsKey(nameKey + cleanedZip)) {
                    matchedAccount = accountsByKey.get(nameKey + cleanedZip);
                } else if (String.isBlank(cleanedZip) && accountsByNameOnly.containsKey(nameKey)) {
                    // Name-only match is allowed ONLY when the lead has no usable zip. A lead that
                    // DOES have a zip but whose same-name account has a different (or blank) zip must
                    // NOT collapse onto that account here -- that mis-files generic names (e.g. a
                    // person typing their first name as the company). Such leads fall through to the
                    // fuzzy Account matching-rule fallback instead.
                    matchedAccount = accountsByNameOnly.get(nameKey);
                }
                if (matchedAccount != null) lc.setAccountId(matchedAccount.Id);
            }
            if (matchedAccount != null && !matchedAccount.Opportunities.isEmpty()) {
                for (Opportunity opp : matchedAccount.Opportunities) {
                    if (opp.Lead_Product_Category_on_Opp__c == l.Lead_Product_Category__c && l.Lead_Product_Category__c != 'Training Course') {
                        lc.setOpportunityId(opp.Id);
                        existingOpps.put(opp.Id, opp);
                        break; // take the most recently modified match; stop after first
                    }
                }
            }
            // Opportunity NAME for new opps is assigned in a single pass AFTER the fuzzy fallback
            // (below). Setting it here would clash with the fuzzy path's setOpportunityId(): once a
            // name is set on a Database.LeadConvert, setOpportunityName(null) does NOT clear it, so a
            // fuzzy-attached lead would carry BOTH an opportunityId and a name and be rejected.
            if (String.isEmpty(l.Campaign_Type__c) || l.Campaign_Type__c == 'UQL') {
                lc.setOpportunityId(null);
                lc.setDoNotCreateOpportunity(true);
            }
            leadsToConvert.add(lc);
        }

        // --- Fuzzy account fallback (Datacloud.FindDuplicates) ---------------------------
        // 4th match path: for leads still unmatched after email-first, name+zip and name-only,
        // ask the org's active Account matching rules for a fuzzy match (e.g. "Legacy Billing"
        // -> "Legacy Billing Co"). Chunked to 50 records/call per the FindDuplicates limit, so
        // 200 leads = max 4 calls; candidate accounts are hydrated in a single extra SOQL.
        List<Lead> fuzzyUnmatchedLeads = new List<Lead>();
        for (Database.LeadConvert lc : leadsToConvert) {
            Lead l = leadMap.get(lc.getLeadId());
            if (lc.getAccountId() == null && l != null && String.isNotBlank(l.Company)
                    && !JUNK_COMPANY_NAMES.contains(l.Company.toLowerCase().trim())) {
                fuzzyUnmatchedLeads.add(l);
            }
        }
        if (!fuzzyUnmatchedLeads.isEmpty()) {
            Map<Id, Account> fuzzyMatchesByLeadId = findFuzzyAccountMatches(fuzzyUnmatchedLeads);
            if (!fuzzyMatchesByLeadId.isEmpty()) {
                for (Database.LeadConvert lc : leadsToConvert) {
                    if (lc.getAccountId() != null) {
                        continue;
                    }
                    Lead l = leadMap.get(lc.getLeadId());
                    Account fuzzyAccount = (l == null) ? null : fuzzyMatchesByLeadId.get(l.Id);
                    if (fuzzyAccount == null) {
                        continue;
                    }
                    lc.setAccountId(fuzzyAccount.Id);
                    // Fuzzy-matched accounts already exist, so don't overwrite their address/subsidiary.
                    preExistingAccountIds.add(fuzzyAccount.Id);
                    // Only attach an existing opp for opportunity-creating leads (mirrors the main
                    // loop, where UQL/blank-campaign-type leads have doNotCreateOpportunity set).
                    Boolean createsOpp = (String.isEmpty(l.Campaign_Type__c) == FALSE) && l.Campaign_Type__c != 'UQL';
                    if (createsOpp && fuzzyAccount.Opportunities != null && !fuzzyAccount.Opportunities.isEmpty()) {
                        for (Opportunity opp : fuzzyAccount.Opportunities) {
                            if (opp.Lead_Product_Category_on_Opp__c == l.Lead_Product_Category__c && l.Lead_Product_Category__c != 'Training Course') {
                                lc.setOpportunityId(opp.Id);
                                existingOpps.put(opp.Id, opp);
                                break;
                            }
                        }
                    }
                }
            }
        }
        // -------------------------------------------------------------------------------

        // --- Intra-batch new-company dedup ----------------------------------------------
        // Two or more leads for the SAME brand-new company in ONE batch would each mint a separate
        // Account, because the fuzzy fallback (FindDuplicates) can only see records already committed
        // to the database -- not siblings being created in this same call. Pre-create ONE shared
        // Account per company group so every member attaches to it; same-product members beyond
        // the first also defer and attach to the first member's new Opportunity (one Account + one
        // Opportunity, not duplicates). Single new-company leads are pre-created the SAME way (a
        // group of one): this fully populates the Account (address + subsidiary) BEFORE conversion,
        // so downstream automation never sees a name-only Account -- closing the two-step account
        // creation window. If the pre-create insert is blocked, the try/catch below falls back to
        // the prior behavior (convertLead mints the Account, then the result loop updates it).
        Set<Id> oppFollowerLeadIds = new Set<Id>();
        Set<Id> newCompanyMultiGroupLeadIds = new Set<Id>();
        Map<Id, String> followerLeadIdToOppKey = new Map<Id, String>();
        Map<String, Id> newCompanyOppKeyToOppId = new Map<String, Id>();
        Map<String, Integer> newCompanyOppFollowerCounts = new Map<String, Integer>();
        Map<String, List<Database.LeadConvert>> newCompanyGroups = new Map<String, List<Database.LeadConvert>>();
        for (Database.LeadConvert lc : leadsToConvert) {
            if (lc.getAccountId() != null) {
                continue; // already matched to an existing account
            }
            Lead l = leadMap.get(lc.getLeadId());
            if (l == null || String.isBlank(l.Company) || JUNK_COMPANY_NAMES.contains(l.Company.toLowerCase().trim())) {
                continue;
            }
            String key = newCompanyKey(l);
            if (!newCompanyGroups.containsKey(key)) {
                newCompanyGroups.put(key, new List<Database.LeadConvert>());
            }
            newCompanyGroups.get(key).add(lc);
        }
        List<Account> newSharedAccounts = new List<Account>();
        List<String> newSharedAccountKeys = new List<String>();
        for (String key : newCompanyGroups.keySet()) {
            List<Database.LeadConvert> groupLcs = newCompanyGroups.get(key);
            Lead firstLead = leadMap.get(groupLcs[0].getLeadId());
            Account a = new Account(Name = firstLead.Company);
            a.ShippingStreet = firstLead.Street;
            a.ShippingCity = firstLead.City;
            a.ShippingState = firstLead.State;
            a.ShippingPostalCode = firstLead.PostalCode;
            a.ShippingCountry = firstLead.Country;
            if (firstLead.Lead_Product_Category__c == 'Enterprise') {
                a.Subsidiary__c = ACCOUNT_SUBSIDIARY_ENTERPRISE;
            } else {
                a.Subsidiary__c = getAccountSubsidiaryByCountry(firstLead.Country);
            }
            newSharedAccounts.add(a);
            newSharedAccountKeys.add(key);
        }
        Boolean sharedAccountsCreated = false;
        if (!newSharedAccounts.isEmpty()) {
            try {
                insert newSharedAccounts;
                sharedAccountsCreated = true;
            } catch (Exception e) {
                // If pre-create is blocked (e.g. an Account validation rule), fall back to the prior
                // behavior (each lead creates its own account) rather than failing the whole batch.
                System.debug(LoggingLevel.ERROR, 'New-company shared account pre-create failed: ' + e.getMessage());
            }
        }
        if (sharedAccountsCreated) {
            for (Integer i = 0; i < newSharedAccounts.size(); i++) {
                String key = newSharedAccountKeys[i];
                Id sharedAcctId = newSharedAccounts[i].Id;
                // Address + subsidiary were set above, so skip the result-loop's new-account update.
                preExistingAccountIds.add(sharedAcctId);
                Set<String> seenOppKeys = new Set<String>();
                for (Database.LeadConvert lc : newCompanyGroups.get(key)) {
                    lc.setAccountId(sharedAcctId);
                    Lead l = leadMap.get(lc.getLeadId());
                    newCompanyMultiGroupLeadIds.add(l.Id);
                    Boolean memberCreatesOpp = (String.isEmpty(l.Campaign_Type__c) == FALSE) && l.Campaign_Type__c != 'UQL';
                    if (!memberCreatesOpp) {
                        continue;
                    }
                    String oppKey = newCompanyOppKey(l);
                    if (seenOppKeys.contains(oppKey)) {
                        // a later same-product member: attach to the first member's opp, not a new one
                        oppFollowerLeadIds.add(l.Id);
                        followerLeadIdToOppKey.put(l.Id, oppKey);
                        Integer cnt = newCompanyOppFollowerCounts.get(oppKey);
                        newCompanyOppFollowerCounts.put(oppKey, (cnt == null ? 0 : cnt) + 1);
                    } else {
                        seenOppKeys.add(oppKey); // first member for this product owns the opp
                    }
                }
            }
        }
        // -------------------------------------------------------------------------------

        // Assign the new-opportunity NAME now that account/opp matching (incl. the fuzzy fallback)
        // is final. Any opp-creating lead still without an opportunityId needs convertLead to mint a
        // new opp; leads that attached to an existing opp keep their opportunityId and get no name,
        // which avoids the "opportunityId and opportunityName, but not both" conversion error.
        for (Database.LeadConvert lc : leadsToConvert) {
            Lead l = leadMap.get(lc.getLeadId());
            if (l == null) {
                continue;
            }
            Boolean createsOpp = (String.isEmpty(l.Campaign_Type__c) == FALSE) && l.Campaign_Type__c != 'UQL';
            // Opp-followers attach to the first member's opp once it exists, so they must NOT get a
            // name now (a name plus a later opportunityId would be rejected as "both").
            if (createsOpp && lc.getOpportunityId() == null && !oppFollowerLeadIds.contains(l.Id)) {
                String oppName = 'Lead - ' + l.Company + ' - ' + l.Lead_Product_Category__c + ' - ' + Datetime.now().format('MMM d, YY');
                lc.setOpportunityName(oppName?.left(120));
            }
        }

        // 2. Query all Campaigns where Name IN :campaignNames
        Map<String, Id> campaignNameToId = new Map<String, Id>();
        if (!campaignNames.isEmpty()) {
            for (Campaign c : [SELECT Id, Name FROM Campaign WHERE Name IN :campaignNames]) {
                campaignNameToId.put(c.Name, c.Id);
            }
        }

        Map<Id, CampaignMember> leadIdToCampaignMember = new Map<Id, CampaignMember>();
        for (CampaignMember cm : [
            SELECT Id, CampaignId, LeadId
            FROM CampaignMember
            WHERE LeadId IN :leadMap.keySet()
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!leadIdToCampaignMember.containsKey(cm.LeadId)) {
                leadIdToCampaignMember.put(cm.LeadId, cm);
            }
        }

        Map<Id,Opportunity> oppsTouchCount = new Map<Id, Opportunity>([SELECT Id, Touch_Count__c FROM Opportunity WHERE Id IN :existingOpps.keySet()]);

        // --- Contact deduplication (Bug 1a + 1b) ----------------------------------------
        // Reuse an existing Contact on the matched Account instead of letting convertLead
        // mint a new one. Scoped by (lowercased email + matched AccountId) so the same email
        // on a different account stays a distinct Contact. See dedup_fix.md.
        Set<String> dedupeLeadEmails = new Set<String>();
        Set<Id> matchedAccountIds = new Set<Id>();
        for (Database.LeadConvert lc : leadsToConvert) {
            Lead l = leadMap.get(lc.getLeadId());
            if (lc.getAccountId() != null && l != null && String.isNotBlank(l.Email)) {
                dedupeLeadEmails.add(l.Email.toLowerCase());
                matchedAccountIds.add(lc.getAccountId());
            }
        }

        Map<String, Id> existingContactByEmailAndAccount = new Map<String, Id>();
        if (!dedupeLeadEmails.isEmpty() && !matchedAccountIds.isEmpty()) {
            for (Contact c : [
                SELECT  Id, Email, AccountId
                FROM    Contact
                WHERE   Email IN :dedupeLeadEmails
                AND     AccountId IN :matchedAccountIds
            ]) {
                String contactKey = c.Email.toLowerCase() + c.AccountId;
                // If an account already has duplicate contacts for this email, keep the first.
                if (!existingContactByEmailAndAccount.containsKey(contactKey)) {
                    existingContactByEmailAndAccount.put(contactKey, c.Id);
                }
            }
        }

        // Split into a first pass and intra-batch followers (Bug 1b). A "follower" is a second+
        // lead in THIS batch sharing an email+account with an earlier lead that has no existing
        // DB Contact -- it must wait until the first lead's conversion creates that Contact.
        Set<String> claimedInBatch = new Set<String>();
        List<Database.LeadConvert> firstPass = new List<Database.LeadConvert>();
        List<Database.LeadConvert> deferredConverts = new List<Database.LeadConvert>();
        for (Database.LeadConvert lc : leadsToConvert) {
            Id matchedAccountId = lc.getAccountId();
            Lead l = leadMap.get(lc.getLeadId());
            if (l != null && oppFollowerLeadIds.contains(l.Id)) {
                // Same-product new-company follower: must convert AFTER the first group member
                // creates the shared account's opp (its opportunityId is wired in below).
                deferredConverts.add(lc);
                continue;
            }
            if (matchedAccountId == null || l == null || String.isBlank(l.Email)) {
                firstPass.add(lc); // no email / no account match -> let convertLead create a new Contact
                continue;
            }
            String contactKey = l.Email.toLowerCase() + matchedAccountId;
            if (existingContactByEmailAndAccount.containsKey(contactKey)) {
                lc.setContactId(existingContactByEmailAndAccount.get(contactKey)); // reuse existing Contact
                firstPass.add(lc);
            } else if (!claimedInBatch.contains(contactKey)) {
                claimedInBatch.add(contactKey); // first in batch -> let it create the Contact
                firstPass.add(lc);
            } else {
                deferredConverts.add(lc); // intra-batch duplicate -> convert after the first one
            }
        }

        // Bug 3: allOrNone = false so one failed record (e.g. a duplicate-rule block) does not
        // roll back the whole batch. Failures are surfaced per-record in the loop below.
        List<Database.LeadConvertResult> lcrs = Database.convertLead(firstPass, false);

        // Harvest Contacts created in the first pass, then convert the deferred followers so they
        // attach to those Contacts instead of minting new duplicates.
        if (!deferredConverts.isEmpty()) {
            for (Database.LeadConvertResult r : lcrs) {
                if (r.isSuccess()) {
                    Lead l = leadMap.get(r.getLeadId());
                    if (l != null && r.getAccountId() != null && String.isNotBlank(l.Email)) {
                        String contactKey = l.Email.toLowerCase() + r.getAccountId();
                        if (!existingContactByEmailAndAccount.containsKey(contactKey)) {
                            existingContactByEmailAndAccount.put(contactKey, r.getContactId());
                        }
                    }
                }
            }
            // Map each new-company group's owner-created Opportunity so same-product followers can
            // attach to it (one shared opp) instead of creating their own duplicates.
            for (Database.LeadConvertResult r : lcrs) {
                if (r.isSuccess() && r.getOpportunityId() != null) {
                    Lead l = leadMap.get(r.getLeadId());
                    if (l != null && newCompanyMultiGroupLeadIds.contains(l.Id) && !oppFollowerLeadIds.contains(l.Id)) {
                        newCompanyOppKeyToOppId.put(newCompanyOppKey(l), r.getOpportunityId());
                    }
                }
            }
            for (Database.LeadConvert lc : deferredConverts) {
                Lead l = leadMap.get(lc.getLeadId());
                // Same-product new-company follower: attach to the owner's freshly created opp. No
                // name was set on it, so setting an opportunityId here is safe.
                if (l != null && oppFollowerLeadIds.contains(l.Id)) {
                    String fOppKey = followerLeadIdToOppKey.get(l.Id);
                    if (fOppKey != null && newCompanyOppKeyToOppId.containsKey(fOppKey)) {
                        lc.setOpportunityId(newCompanyOppKeyToOppId.get(fOppKey));
                    }
                }
                if (l != null && String.isNotBlank(l.Email)) {
                    String contactKey = l.Email.toLowerCase() + lc.getAccountId();
                    if (existingContactByEmailAndAccount.containsKey(contactKey)) {
                        lc.setContactId(existingContactByEmailAndAccount.get(contactKey));
                    }
                }
                // If the first-pass conversion failed (no Contact created), this falls through and
                // convertLead creates a new Contact -- no worse than the pre-fix behavior.
            }
            lcrs.addAll(Database.convertLead(deferredConverts, false));
        }
        // --------------------------------------------------------------------------------
        Map<ID, Opportunity> oppIdUpdateMap = new Map<ID, Opportunity>();
        // Number of successful batch leads matching each EXISTING opp, so Touch_Count__c can be
        // base + total touches instead of base + 1 (getOpp only runs for the first matching lead).
        Map<Id, Integer> existingOppTouchHits = new Map<Id, Integer>();
        // leadId -> oppId so the returned list can be rebuilt in the original input order.
        // The dedup split reorders lcrs (firstPass then deferredConverts), so iterating lcrs
        // directly would break positional alignment with the input leads list.
        Map<Id, Id> leadIdToOppId = new Map<Id, Id>();
        List<Id> contactIds = new List<Id>();
        Map<ID, Account> accIdUpdateMap = new Map<ID, Account>();
        Set<Id> uqlContacts = New Set<Id>();
        Map<Id, Lead> contactIdToLead = new Map<Id, Lead>();

        for (Database.LeadConvertResult lcr : lcrs) {
            ID leadId = lcr.getLeadId();
            ID oppId = lcr.getOpportunityId();
            ID accId = lcr.getAccountId();
            Id contactId = lcr.getContactId();
            if (contactId != null) {
                contactIds.add(contactId);
                contactIdToLead.put(contactId, leadMap.get(leadId));
                if (oppId == null) {
                    uqlContacts.add(contactId);
                }
            }

            if (lcr.isSuccess()) {
                Lead lead = leadMap.get(leadId);
                if (oppId != null) {
                    if (existingOpps.containsKey(oppId)) {
                        Integer hits = existingOppTouchHits.get(oppId);
                        existingOppTouchHits.put(oppId, (hits == null ? 0 : hits) + 1);
                    }
                    // Pass campaignNameToId to getOpp
                    Opportunity opp = getOpp(lead, oppId, existingOpps, OPPORTUNITY_LEAD_RECORD_TYPE_ID, oppsTouchCount, leadIdToCampaignMember, campaignNameToId);
                    if (opp.Id != null && !oppIdUpdateMap.containsKey(opp.Id)) {
                        oppIdUpdateMap.put(opp.Id, opp);
                    }
                }

                if (accId != null) {
                    Account acc = new Account(Id = accId);
                    if (!preExistingAccountIds.contains(accId)) {
                        acc.ShippingStreet = lead.Street;
                        acc.ShippingCity = lead.City;
                        acc.ShippingState = lead.State;
                        acc.ShippingPostalCode = lead.PostalCode;
                        acc.ShippingCountry = lead.Country;
                        // Determine subsidiary based on country (replacing the flow logic)
                        if (lead.Lead_Product_Category__c == 'Enterprise') {
                            acc.Subsidiary__c = ACCOUNT_SUBSIDIARY_ENTERPRISE;
                        } else {
                            acc.Subsidiary__c = getAccountSubsidiaryByCountry(lead.Country);
                        }
                    }
                    if (!accIdUpdateMap.containsKey(accId)) {
                        accIdUpdateMap.put(accId, acc);
                    }
                }
            } else {
                // Bug 3: per-record failure -- log and continue so one bad lead does not sink
                // the rest of the batch. No suitable custom error-log object exists in the org,
                // so System.debug at ERROR is the sink for now (see dedup_fix.md).
                String errMsgs = '';
                for (Database.Error err : lcr.getErrors()) {
                    errMsgs += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
                System.debug(LoggingLevel.ERROR, 'LeadConvert failed for Lead ' + leadId + ' -> ' + errMsgs);
            }
            leadIdToOppId.put(leadId, oppId);
        }

        // Rebuild in input order so oppIds[i] corresponds to leads[i]. Leads that produced no
        // opportunity (or failed conversion) yield null, keeping the list size equal to input.
        List<Id> oppIds = new List<Id>();
        for (Lead l : leads) {
            oppIds.add(leadIdToOppId.get(l.Id));
        }

        // Apply the full batch touch count for existing opps hit by more than one lead. getOpp
        // already set base + 1 for the first lead; overwrite with base + total hits here.
        for (Id existingOppId : existingOppTouchHits.keySet()) {
            Opportunity oppToUpdate = oppIdUpdateMap.get(existingOppId);
            if (oppToUpdate != null) {
                Decimal baseTouches = oppsTouchCount.get(existingOppId)?.Touch_Count__c ?? 0;
                oppToUpdate.Touch_Count__c = baseTouches + existingOppTouchHits.get(existingOppId);
            }
        }

        // New-company groups: the owner created the shared opp with Touch_Count 1; add one touch per
        // same-product follower that attached to it in this batch.
        for (String ncOppKey : newCompanyOppKeyToOppId.keySet()) {
            Opportunity oppToUpdate = oppIdUpdateMap.get(newCompanyOppKeyToOppId.get(ncOppKey));
            Integer followerCount = newCompanyOppFollowerCounts.get(ncOppKey);
            if (oppToUpdate != null && followerCount != null) {
                oppToUpdate.Touch_Count__c = 1 + followerCount;
            }
        }

        List<Contact> conList = [SELECT Id, MQL_SQL__c, UQL_Count__c, Form_Product__c FROM Contact WHERE Id IN :contactIds];
        List<Contact> consToUpdate = new List<Contact>();
        for (Contact con : conList) {
            if(uqlContacts.contains(con.id)) {
                con.UQL_Count__c = 1;
            } else {
                con.MQL_SQL__c = 1;
            }
            Lead sourceLead = contactIdToLead.get(con.Id);
            if (sourceLead != null) {
                // Option 2: always reflect the latest form submission on the Contact, even when blank.
                // This intentionally overwrites a previously known value so the Contact represents
                // the most recent interaction (not the oldest known product).
                con.Form_Product__c = sourceLead.Form_Product__c;
            }
            consToUpdate.add(con);
        }

        // Partial-success on all three post-convert updates: one blocked record (validation rule,
        // FLS, a downstream trigger error) must not silently sink every opp/account/contact update
        // in the batch. Failures are logged per-record rather than swallowed whole.
        if (!oppIdUpdateMap.isEmpty()) {
            List<Opportunity> oppsToUpdate = oppIdUpdateMap.values();
            Database.SaveResult[] oppResults = Database.update(oppsToUpdate, false);
            for (Integer i = 0; i < oppResults.size(); i++) {
                if (!oppResults[i].isSuccess()) {
                    String errMsgs = '';
                    for (Database.Error err : oppResults[i].getErrors()) {
                        errMsgs += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    System.debug(LoggingLevel.ERROR, 'Opportunity update failed for ' + oppsToUpdate[i].Id + ' -> ' + errMsgs);
                }
            }
        }
        if (!accIdUpdateMap.isEmpty()) {
            List<Account> accsToUpdate = accIdUpdateMap.values();
            Database.SaveResult[] accResults = Database.update(accsToUpdate, false);
            for (Integer i = 0; i < accResults.size(); i++) {
                if (!accResults[i].isSuccess()) {
                    String errMsgs = '';
                    for (Database.Error err : accResults[i].getErrors()) {
                        errMsgs += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    System.debug(LoggingLevel.ERROR, 'Account update failed for ' + accsToUpdate[i].Id + ' -> ' + errMsgs);
                }
            }
        }
        if (!consToUpdate.isEmpty()) {
            Database.SaveResult[] conResults = Database.update(consToUpdate, false);
            for (Integer i = 0; i < conResults.size(); i++) {
                if (!conResults[i].isSuccess()) {
                    String errMsgs = '';
                    for (Database.Error err : conResults[i].getErrors()) {
                        errMsgs += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    System.debug(LoggingLevel.ERROR, 'Contact update failed for ' + consToUpdate[i].Id + ' -> ' + errMsgs);
                }
            }
        }
        return oppIds;
    }
    
    public static Opportunity getOpp(Lead l, ID opportunityId, Map<Id,Opportunity> existingOpps, String leadRecordTypeId, Map<Id,Opportunity> oppsTouchCount, Map<Id, CampaignMember> leadIdToCampaignMember, Map<String, Id> campaignNameToId) {
        Opportunity opp = new Opportunity();

        if (existingOpps.containsKey(opportunityId)) {
            /*Update Stage to “New”
            Append Lead Product of Interest with new values from Lead
            Set Sales Rep to Assign with value from Lead*/
            Opportunity existingOpp = existingOpps.get(opportunityId);
            opp.Id = opportunityId;
            opp.Lead_Sales_Rep_to_Assign__c = l.Lead_Sales_Rep_to_Assign__c;
            opp.StageName = 'New';
            if (l.Lead_Product_Category__c != 'Training Course') {
                opp.Training_Course_Date__c = null;
                opp.Training_Course_Location__c = null;
                opp.Training_Course_Name__c = null;
            }
            opp.Lead_Campaign_Type__c = l.Campaign_Type__c?.left(255);
            opp.Pardot_Campaign__c = l.pi__campaign__c?.left(255);
            opp.Last_Registered_Event__c = l.Last_Registered_Event__c;
            opp.Last_Attended_Trade_Show__c = l.Last_Attended_Trade_Show__c;
            opp.LSC_Campaign__c = l.LSC_Campaign__c?.left(255);
            opp.Touch_Count__c = (oppsTouchCount.get(opportunityId)?.Touch_Count__c ?? 0) + 1;
            opp.GCLID_Google_Click_Identification__c = l.GCLID_Google_Click_Identification__c?.left(255);
            opp.Google_Analytics_Campaign__c = l.pi__utm_campaign__c?.left(255);
            opp.Google_Analytics_Medium__c = l.pi__utm_medium__c?.left(255);
            opp.Google_Analytics_Referrer__c = l.Google_Analytics_Referrer__c?.left(255);
            opp.Google_Analytics_Source__c = l.pi__utm_source__c?.left(255);
            opp.Google_Analytics_Term__c = l.pi__utm_term__c?.left(255);
            opp.NDA__c = l.Send_NDA__c;
            opp.TD_Lead_Score__c = l.TD_Lead_Score__c;
            // Option 2 consistency: always reflect the latest form product on the existing opp,
            // matching the Contact.Form_Product__c behavior below (overwrites even when blank).
            opp.Form_Product__c = l.Form_Product__c;

            if (l.Lead_Product_Category__c == LPC_DESIGN) {
                String td_notes = 'Lead Funding: ' + l.TD_Lead_Funding__c + ' | Lead Inquiry: ' + l.TD_Lead_Inquiry__c + 
                        ' | Lead Persona: ' + l.TD_Lead_Persona__c + ' | Lead Product Description: ' + l.TD_Lead_Product_Description__c +
                        ' | Lead Product Stage: ' + l.TD_Lead_Product_Stage__c;
                
                if (existingOpp.TD_Lead_Notes__c != null) {
                    opp.TD_Lead_Notes__c = existingOpp.TD_Lead_Notes__c + ' || ' + td_notes;
                } else {
                    opp.TD_Lead_Notes__c = td_notes;
                }
            }

            // Preserve the existing opp's Primary Campaign Source (first-touch attribution):
            // only set CampaignId when the opp doesn't already have one. Mirrors the LeadSource
            // rule below. Without this, every later lead attaching to the opp would overwrite the
            // original campaign source.
            if (existingOpp.CampaignId == null) {
                if(leadIdToCampaignMember.containsKey(l.Id)) {
                    CampaignMember cm = leadIdToCampaignMember.get(l.Id);
                    opp.CampaignId = cm.CampaignId;
                } else if (String.isNotBlank(l.pi__campaign__c) && campaignNameToId != null && campaignNameToId.containsKey(l.pi__campaign__c.trim())) {
                    opp.CampaignId = campaignNameToId.get(l.pi__campaign__c.trim());
                }
            }
            
            if (String.isBlank(existingOpp.LeadSource)) opp.LeadSource = l.LeadSource;
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
            //Set fields for new opportunities
            opp.Id = opportunityId;
            opp.CloseDate = Date.today().addDays(30);
            opp.RecordTypeId = leadRecordTypeId;
            opp.Description = l.pi__comments__c;
            opp.Touch_Count__c = 1;
            opp.Form_Product__c = l.Form_Product__c;
            if (l.Lead_Product_Category__c == 'Training Course') {
                opp.Training_Course_Date__c = l.Training_Course_Date__c;
                opp.Training_Course_Location__c = l.Training_Course_Location__c;
                opp.Training_Course_Name__c = l.Training_Course_Name__c;
            }
            if (l.Lead_Product_Category__c == LPC_DESIGN) {
                opp.TD_Lead_Notes__c = 'Lead Funding: ' + l.TD_Lead_Funding__c + ' | Lead Inquiry: ' + l.TD_Lead_Inquiry__c + 
                        ' | Lead Persona: ' + l.TD_Lead_Persona__c + ' | Lead Product Description: ' + l.TD_Lead_Product_Description__c +
                        ' | Lead Product Stage: ' + l.TD_Lead_Product_Stage__c;
            }
            if(leadIdToCampaignMember.containsKey(l.Id)) {
                CampaignMember cm = leadIdToCampaignMember.get(l.Id);
                opp.CampaignId = cm.CampaignId;
            } else if (String.isNotBlank(l.pi__campaign__c) && campaignNameToId != null && campaignNameToId.containsKey(l.pi__campaign__c.trim())) {
                opp.CampaignId = campaignNameToId.get(l.pi__campaign__c.trim());
            }
        }

        return opp;
    }

    public static Map<String,Account> getAccountsByKey(Set<String> leadCompanyNames) {
        List<Account> existingAccounts = [
            SELECT  Id, Name, LastActivityDate, Subsidiary__c, BillingStreet, BillingCity,
                    BillingState, BillingPostalCode, BillingCountry, ShippingStreet, ShippingCity,
                    ShippingState, ShippingPostalCode, ShippingCountry, 
                        (SELECT  Id, Name, Lead_Product_Category_on_Opp__c, LeadSource,
                            Lead_Sales_Rep_to_Assign__c, StageName, Lead_Product_of_Interest_on_Opp__c,
                            Description, Pardot_Campaign__c, LSC_Campaign__c, CampaignId,
                            GCLID_Google_Click_Identification__c, Google_Analytics_Campaign__c,
                            Google_Analytics_Medium__c, Google_Analytics_Referrer__c, Google_Analytics_Source__c,
                            Google_Analytics_Term__c, NDA__c, TD_Lead_Score__c, TD_Lead_Notes__c
                        FROM    Opportunities
                        WHERE   StageName IN :OPPORTUNITY_STAGE_NAMES
                        AND     RecordTypeId = :OPPORTUNITY_LEAD_RECORD_TYPE_ID
                        ORDER BY LastModifiedDate DESC
                        )
            FROM        Account 
            WHERE       Name IN :leadCompanyNames 
            ORDER BY    LastActivityDate DESC
        ];
        Map<String,Account> accountsByKey = new Map<String,Account>();
        for (Account a : existingAccounts) {
            // Bug 2: prefer Shipping, fall back to Billing when the Shipping zip is blank, so
            // legacy billing-only accounts (~18k) can match an incoming lead. Pivoting on the
            // Shipping zip keeps the key identical for accounts that already have one (no regression).
            String matchCountry = String.isNotBlank(a.ShippingPostalCode) ? a.ShippingCountry : a.BillingCountry;
            String matchZip = String.isNotBlank(a.ShippingPostalCode) ? a.ShippingPostalCode : a.BillingPostalCode;
            String key = a.Name.toLowerCase() + getCleanedZip(matchCountry, matchZip);
            if (!accountsByKey.containsKey(key)) {
                accountsByKey.put(key,a);
            }
        }
        return accountsByKey;
    }

    // Fuzzy account fallback driven by the org's active Account matching rules. Returns a map of
    // leadId -> best-match existing Account (hydrated with its candidate opportunities), for the
    // subset of leads that have one. FindDuplicates does NOT consume the SOQL counter and is
    // capped at 50 records/call, so probes are chunked; candidate accounts are then hydrated in a
    // single SOQL using the same opp subquery as getAccountsByKey().
    private static Map<Id, Account> findFuzzyAccountMatches(List<Lead> unmatchedLeads) {
        Map<Id, Account> matchedAccountByLeadId = new Map<Id, Account>();
        if (unmatchedLeads == null || unmatchedLeads.isEmpty()) {
            return matchedAccountByLeadId;
        }

        // Build throwaway, in-memory Account probes (never inserted) carrying the lead's company
        // name + address so sparse-address matching rules still have something to fire on.
        List<Account> probes = new List<Account>();
        List<Id> probeLeadIds = new List<Id>();
        for (Lead l : unmatchedLeads) {
            // Populate BOTH Billing and Shipping so the Billing-based and Shipping-based
            // matching rules can each fire against the probe.
            probes.add(new Account(
                Name = l.Company,
                BillingStreet = l.Street,
                BillingCity = l.City,
                BillingState = l.State,
                BillingPostalCode = l.PostalCode,
                BillingCountry = l.Country,
                ShippingStreet = l.Street,
                ShippingCity = l.City,
                ShippingState = l.State,
                ShippingPostalCode = l.PostalCode,
                ShippingCountry = l.Country
            ));
            probeLeadIds.add(l.Id);
        }

        Map<Id, Id> leadIdToCandidateAccountId = new Map<Id, Id>();
        Map<Id, Double> leadIdToBestConfidence = new Map<Id, Double>();
        Set<Id> candidateAccountIds = new Set<Id>();
        Integer chunkSize = 50;
        for (Integer start = 0; start < probes.size(); start += chunkSize) {
            Integer stop = Math.min(start + chunkSize, probes.size());
            List<SObject> chunk = new List<SObject>();
            List<Id> chunkLeadIds = new List<Id>();
            for (Integer j = start; j < stop; j++) {
                chunk.add(probes[j]);
                chunkLeadIds.add(probeLeadIds[j]);
            }
            try {
                List<Datacloud.FindDuplicatesResult> fdResults = Datacloud.FindDuplicates.findDuplicates(chunk);
                // findDuplicates returns one result per input record, in input order.
                for (Integer k = 0; k < fdResults.size(); k++) {
                    Id leadId = chunkLeadIds[k];
                    for (Datacloud.DuplicateResult dr : fdResults[k].getDuplicateResults()) {
                        for (Datacloud.MatchResult mr : dr.getMatchResults()) {
                            for (Datacloud.MatchRecord rec : mr.getMatchRecords()) {
                                SObject candidate = rec.getRecord();
                                if (candidate == null || candidate.Id == null
                                        || candidate.getSObjectType() != Account.SObjectType) {
                                    continue;
                                }
                                Double conf = rec.getMatchConfidence();
                                Double best = leadIdToBestConfidence.get(leadId);
                                if (best == null || (conf != null && conf > best)) {
                                    leadIdToCandidateAccountId.put(leadId, candidate.Id);
                                    leadIdToBestConfidence.put(leadId, conf == null ? 0 : conf);
                                }
                                candidateAccountIds.add(candidate.Id);
                            }
                        }
                    }
                }
            } catch (Exception e) {
                // Matching rules may be inactive/misconfigured -- fall through to new-account
                // creation (current behavior) rather than failing the whole conversion batch.
                System.debug(LoggingLevel.ERROR, 'FindDuplicates fuzzy match failed: ' + e.getMessage());
            }
        }

        if (candidateAccountIds.isEmpty()) {
            return matchedAccountByLeadId;
        }

        Map<Id, Account> hydratedAccounts = new Map<Id, Account>([
            SELECT Id, Name,
                (SELECT  Id, Name, Lead_Product_Category_on_Opp__c, LeadSource,
                        Lead_Sales_Rep_to_Assign__c, StageName, Lead_Product_of_Interest_on_Opp__c,
                        Description, Pardot_Campaign__c, LSC_Campaign__c, CampaignId,
                        GCLID_Google_Click_Identification__c, Google_Analytics_Campaign__c,
                        Google_Analytics_Medium__c, Google_Analytics_Referrer__c, Google_Analytics_Source__c,
                        Google_Analytics_Term__c, NDA__c, TD_Lead_Score__c, TD_Lead_Notes__c
                 FROM Opportunities
                 WHERE StageName IN :OPPORTUNITY_STAGE_NAMES
                 AND   RecordTypeId = :OPPORTUNITY_LEAD_RECORD_TYPE_ID
                 ORDER BY LastModifiedDate DESC)
            FROM Account
            WHERE Id IN :candidateAccountIds
        ]);

        for (Id leadId : leadIdToCandidateAccountId.keySet()) {
            Account a = hydratedAccounts.get(leadIdToCandidateAccountId.get(leadId));
            if (a != null) {
                matchedAccountByLeadId.put(leadId, a);
            }
        }
        return matchedAccountByLeadId;
    }

    public static Set<String> getLeadCompanyNames(List<Lead> leads) {
        Set<String> leadCompanyNames = new Set<String>();
        for (Lead l : leads) {
            if (String.isNotBlank(l.Company) && !JUNK_COMPANY_NAMES.contains(l.Company.toLowerCase().trim())) {
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