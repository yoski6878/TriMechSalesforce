@isTest
public class LeadConvertInvocable_UnitTests {
    @TestSetup
    public static void makeData(){
        Account a = new Account(Name = 'Test Company', ShippingPostalCode = '12345');
        Account b = new Account(Name = 'Test Company 2', ShippingPostalCode = '12346');
        insert new List<Account> {a,b};
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Neglected', CloseDate = Date.today(), AccountId = a.Id, Lead_Product_Category_on_Opp__c = 'DraftSight', Lead_Product_of_Interest_on_Opp__c = 'DraftSight Enterprise');
        insert opp;

        Product_Group__c pg = new Product_Group__c(Name='Software');
        insert pg;

        Pardot_Lead_ASsignment__c PLA = new Pardot_Lead_Assignment__c(Name='DraftSight', PLA_Product_Group__c=pg.id, Assignment_Group__c = 'Software', Sales_Rep_to_Assign__c = 'Software', Solution_Type__c='Standard');
        insert PLA;
    }

    @isTest
    public static void it_should_convert_one_matching_lead() {
        Lead l = new Lead(
            Company = 'Test Company',
            Email = 'test@example.com',
            LastName = 'Test1',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus',
            Campaign_Type__c = 'MQL',
            Status='Unqualified'
        );
        insert l;
        system.debug('LeadConvertInvocable_UnitTests: ' + l);

        System.assert(l.id != null);

        Lead l2 = new Lead(
            Company = 'Test Company',
            Email = 'test2@example.com',
            LastName = 'Test2',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus',
            Campaign_Type__c = 'UQL',
            Status = 'Unqualified'
        );
        insert l2;
        system.debug('LeadConvertInvocable_UnitTests: ' + l2);
        String fakeFlowId = 'abcdefg1234';

        l.Status='New';
        l2.Status='New';
        update new List<Lead>{l, l2};

        List<Lead> newLeads = new List<Lead>();
        newLeads.add(l);
        newLeads.add(l2);

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.leadList = newLeads;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>();
        requests.add(req);
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 1 Response should be returned
        System.assertEquals(1, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // Flow ID should match request
        System.assertEquals(fakeFlowId, resp.flowInterviewId);

        // LeadConvertBatch job should be created
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        List<Lead> convertedLeads = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id = :l.Id OR id = :l2.id
        ];

        // Lead shuold be converted
        System.assertEquals(2, convertedLeads.size());
        System.assertEquals(true, convertedLeads[0].IsConverted);
        System.assertEquals(true, convertedLeads[1].IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should only be 1 Opp still
        System.assertEquals(1, opps.size());
    }

    // Helper: run the invocable end-to-end (kicks off + executes the batch) for the given leads.
    private static void convertViaInvocable(List<Lead> leadsToConvert) {
        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.leadList = leadsToConvert;
        req.flowInterviewId = 'test-flow';
        Test.startTest();
        LeadConvertInvocable.batchConvertLeads(new List<LeadConvertInvocable.InvocationRequest>{ req });
        Test.stopTest();
    }

    private static Lead buildLead(String email, String lastName) {
        return new Lead(
            Company = 'Test Company',
            Email = email,
            LastName = lastName,
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL', // UQL -> DoNotCreateOpportunity, keeps these tests Contact-focused
            Status = 'New'
        );
    }

    @isTest
    public static void it_should_reuse_existing_contact_on_matched_account() {
        // Bug 1a: an existing Contact with the same email on the matched Account is reused,
        // not duplicated.
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];
        Contact existing = new Contact(LastName = 'Existing', Email = 'dup@example.com', AccountId = a.Id);
        insert existing;

        Lead l = buildLead('dup@example.com', 'DupLead');
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'dup@example.com' AND AccountId = :a.Id];
        Assert.areEqual(1, contacts.size(), 'Existing contact should be reused, not duplicated');

        Lead converted = [SELECT Id, IsConverted, ConvertedContactId, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should be converted');
        Assert.areEqual(existing.Id, converted.ConvertedContactId, 'Lead should convert onto the existing contact');
        Assert.areEqual(a.Id, converted.ConvertedAccountId, 'Lead should convert onto the matched account');
    }

    @isTest
    public static void it_should_dedupe_two_same_person_leads_in_one_batch() {
        // Bug 1b: two leads with the same email + matched account, no existing Contact, in one
        // batch -> only ONE Contact is created (intra-batch dedup via two-phase convert).
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];

        Lead l1 = buildLead('intra@example.com', 'Intra1');
        Lead l2 = buildLead('intra@example.com', 'Intra2');
        insert new List<Lead>{ l1, l2 };

        convertViaInvocable(new List<Lead>{ l1, l2 });

        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'intra@example.com' AND AccountId = :a.Id];
        Assert.areEqual(1, contacts.size(), 'Two same-person leads in one batch should yield one contact');

        List<Lead> converted = [
            SELECT Id, IsConverted, ConvertedContactId
            FROM Lead WHERE Id IN (:l1.Id, :l2.Id)
        ];
        Assert.areEqual(2, converted.size(), 'Both leads should be returned');
        for (Lead cl : converted) {
            Assert.isTrue(cl.IsConverted, 'Both leads should be converted');
            Assert.areEqual(contacts[0].Id, cl.ConvertedContactId, 'Both leads should point at the same contact');
        }
    }

    @isTest
    public static void it_should_prefer_email_over_company_name_when_accounts_differ() {
        // Email-first takes priority over name+zip when they point to different accounts.
        // The person already exists in the system (contact on Test Company 2), so email-first
        // routes to that account even though the lead's company name matches Test Company by
        // name+zip. Trusting email over a typed company name is the safer dedup choice.
        Account other = [SELECT Id FROM Account WHERE Name = 'Test Company 2' LIMIT 1];
        Contact onOther = new Contact(LastName = 'Other', Email = 'cross@example.com', AccountId = other.Id);
        insert onOther;

        Lead l = buildLead('cross@example.com', 'Cross'); // Company = 'Test Company', PostalCode = '12345'
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT Id, ConvertedContactId, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.areEqual(other.Id, converted.ConvertedAccountId, 'Email-first should route to the contact\'s account, not the name+zip match');
        Assert.areEqual(onOther.Id, converted.ConvertedContactId, 'Existing contact should be reused via email-first + contact dedup');
    }

    @isTest
    public static void it_should_match_billing_only_account() {
        // Bug 2: an account with a Billing zip but no Shipping zip should still match (and not
        // spawn a duplicate account).
        Account billingOnly = new Account(Name = 'Billing Only Co', BillingPostalCode = '54321');
        insert billingOnly;

        Lead l = new Lead(
            Company = 'Billing Only Co',
            Email = 'bill@example.com',
            LastName = 'Biller',
            PostalCode = '54321',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL',
            Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Billing Only Co'];
        Assert.areEqual(1, accounts.size(), 'Billing-only account should be matched, not duplicated');

        Lead converted = [SELECT Id, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.areEqual(billingOnly.Id, converted.ConvertedAccountId, 'Lead should convert onto the billing-only account');
    }

    @isTest
    public static void it_should_create_new_account_with_subsidiary_and_opp_when_unmatched() {
        // Covers the no-account-match branch of the dedup split (firstPass + continue), the
        // new-account subsidiary helper, and the new-Opportunity name path.
        Lead caLead = new Lead(
            Company = 'Brand New Canada Co', Email = 'ca@example.com', LastName = 'CanadaCo',
            PostalCode = 'N6P1P2', Country = 'Canada',
            Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        Lead usLead = new Lead(
            Company = 'Brand New US Co', Email = 'us@example.com', LastName = 'USCo',
            PostalCode = '99999', Country = 'United States',
            Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert new List<Lead>{ caLead, usLead };

        convertViaInvocable(new List<Lead>{ caLead, usLead });

        Lead ca = [SELECT IsConverted, ConvertedAccountId, ConvertedOpportunityId FROM Lead WHERE Id = :caLead.Id];
        Lead us = [SELECT IsConverted, ConvertedAccountId FROM Lead WHERE Id = :usLead.Id];
        Assert.isTrue(ca.IsConverted && us.IsConverted, 'Both unmatched leads should convert');
        Assert.isNotNull(ca.ConvertedOpportunityId, 'A new opportunity should be created for a non-UQL lead');

        Account caAcc = [SELECT Subsidiary__c FROM Account WHERE Id = :ca.ConvertedAccountId];
        Account usAcc = [SELECT Subsidiary__c FROM Account WHERE Id = :us.ConvertedAccountId];
        Assert.areEqual(LeadConvert.SUBSIDIARY_JAVELIN, caAcc.Subsidiary__c, 'Canada -> Javelin');
        Assert.areEqual(LeadConvert.SUBSIDIARY_TRI_MECH, usAcc.Subsidiary__c, 'US -> TriMech');
    }

    @isTest
    public static void it_should_assign_campaign_from_pardot_and_member() {
        // Covers the pi__campaign__c collection, the Campaign-by-name query, and the
        // CampaignMember lookup paths.
        Campaign camp = new Campaign(Name = 'Pardot Camp', IsActive = true);
        insert camp;

        Lead l = new Lead(
            Company = 'Test Company', Email = 'camp@example.com', LastName = 'Camp',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', pi__campaign__c = 'Pardot Camp', Status = 'New'
        );
        insert l;
        insert new CampaignMember(CampaignId = camp.Id, LeadId = l.Id);

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, ConvertedOpportunityId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.isNotNull(converted.ConvertedOpportunityId, 'Should attach to the matched existing opportunity');
    }

    @isTest
    public static void it_should_use_email_first_when_lead_has_no_zip() {
        // Email-first: existing contact on account, lead has no zip -> routes via email,
        // no duplicate account or contact created.
        Account a = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];
        Contact existing = new Contact(LastName = 'EmailFirst', Email = 'emailfirst@example.com', AccountId = a.Id);
        insert existing;

        Lead l = new Lead(
            Company = 'Test Company',
            Email = 'emailfirst@example.com',
            LastName = 'NoZip',
            PostalCode = null, // no zip — name+zip would produce no match
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL',
            Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, ConvertedAccountId, ConvertedContactId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual(a.Id, converted.ConvertedAccountId, 'Email-first should route to the contact\'s account even without zip');
        Assert.areEqual(existing.Id, converted.ConvertedContactId, 'Existing contact should be reused via email-first + contact dedup');

        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'emailfirst@example.com' AND AccountId = :a.Id];
        Assert.areEqual(1, contacts.size(), 'No duplicate contact should be created');
    }

    @isTest
    public static void it_should_match_account_by_name_only_when_no_zip() {
        // Zip-optional fallback: first-time visitor, no zip on lead, existing account has a zip
        // -> name-only map picks up the account, no duplicate created.
        Account a = new Account(Name = 'Zip Only Co', ShippingPostalCode = '99001');
        insert a;

        Lead l = new Lead(
            Company = 'Zip Only Co',
            Email = 'zipless@example.com',
            LastName = 'ZipLess',
            PostalCode = null, // no zip — would not match by name+zip
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL',
            Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'Zip Only Co'];
        Assert.areEqual(1, accounts.size(), 'Name-only fallback should match the existing account, not create a duplicate');

        Lead converted = [SELECT IsConverted, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual(a.Id, converted.ConvertedAccountId, 'Lead should attach to the existing account via name-only match');
    }

    @isTest
    public static void it_should_not_name_only_match_when_lead_has_different_zip() {
        // Regression (June 2026, "Jim" case): a lead WITH a zip must NOT collapse onto a same-name
        // account whose zip differs. The name-only fallback is gated on String.isBlank(cleanedZip),
        // so this lead instead creates/routes to its own account rather than mis-filing onto the
        // unrelated same-name account.
        Account ontarioJim = new Account(
            Name = 'Jim', ShippingPostalCode = 'N3S0A3', ShippingCountry = 'Canada'
        );
        insert ontarioJim;

        Lead l = new Lead(
            Company = 'Jim', // first name typed as company
            Email = 'jetmay28@example.com',
            LastName = 'Thomson',
            PostalCode = 'V1B0A5', Country = 'Canada', // British Columbia, different zip
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL',
            Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areNotEqual(ontarioJim.Id, converted.ConvertedAccountId,
            'A zipped lead must NOT name-only match an unrelated same-name account with a different zip');
    }

    @isTest
    public static void it_should_not_match_junk_company_name() {
        // Junk name blocklist: a lead with a placeholder company (INDIVIDUAL) must never
        // match the existing INDIVIDUAL account — a new account is created instead.
        Account junk = new Account(Name = 'INDIVIDUAL', ShippingPostalCode = '12345');
        insert junk;

        Lead l = new Lead(
            Company = 'INDIVIDUAL',
            Email = 'junk@example.com',
            LastName = 'JunkCo',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'UQL',
            Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should still convert even with a junk company name');
        Assert.areNotEqual(junk.Id, converted.ConvertedAccountId, 'Junk company name should never match an existing account');
    }

    @isTest
    public static void it_should_log_and_continue_when_a_conversion_fails() {
        // Bug 3: force a per-record failure (an already-converted lead) and assert the rest of
        // the batch still converts -> exercises allOrNone=false + the failure-logging branch.
        Lead good = buildLead('good@example.com', 'GoodLead');
        Lead bad  = buildLead('bad@example.com', 'AlreadyConverted');
        insert new List<Lead>{ good, bad };

        // Pre-convert 'bad' so the batch's convertLead returns a failure for it.
        Database.LeadConvert pre = new Database.LeadConvert();
        pre.setLeadId(bad.Id);
        pre.setConvertedStatus(LeadConvert.LEAD_STATUS_CONVERT.MasterLabel);
        pre.setDoNotCreateOpportunity(true);
        Database.convertLead(pre);

        convertViaInvocable(new List<Lead>{ good, bad });

        Lead goodAfter = [SELECT IsConverted FROM Lead WHERE Id = :good.Id];
        Assert.isTrue(goodAfter.IsConverted, 'Good lead should still convert even though another record failed');
    }

    @isTest
    public static void it_should_preserve_existing_opp_campaign_source() {
        // Campaign-source preservation: a lead attaching to an existing opp that ALREADY has a
        // Primary Campaign Source must NOT overwrite it with the lead's newer campaign.
        Campaign original = new Campaign(Name = 'Original Campaign', IsActive = true);
        Campaign newer = new Campaign(Name = 'Newer Campaign', IsActive = true);
        insert new List<Campaign>{ original, newer };

        Account acc = new Account(Name = 'Campaign Keep Co', ShippingPostalCode = '34567');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Existing Opp', StageName = 'New', CloseDate = Date.today().addDays(10),
            AccountId = acc.Id, RecordTypeId = LeadConvert.OPPORTUNITY_LEAD_RECORD_TYPE_ID,
            Lead_Product_Category_on_Opp__c = 'DraftSight', CampaignId = original.Id
        );
        insert opp;

        Lead l = new Lead(
            Company = 'Campaign Keep Co', Email = 'keep@example.com', LastName = 'Keep',
            PostalCode = '34567', Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', pi__campaign__c = 'Newer Campaign', Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, ConvertedOpportunityId FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual(opp.Id, converted.ConvertedOpportunityId, 'Lead should attach to the existing opp');

        Opportunity afterConvert = [SELECT CampaignId FROM Opportunity WHERE Id = :opp.Id];
        Assert.areEqual(original.Id, afterConvert.CampaignId,
            'Existing opp Primary Campaign Source must be preserved, not overwritten by the new lead');
    }

    @isTest
    public static void it_should_share_one_account_for_same_new_company_in_batch() {
        // Intra-batch new-company dedup: two leads for the SAME brand-new company + same product
        // in one batch share ONE new account and ONE opportunity (touch count = 2), instead of
        // creating duplicate accounts. Uses a unique name so no existing/fuzzy match interferes.
        String co = 'Zzqx Unique Co 778899';
        Lead l1 = new Lead(
            Company = co, Email = 'share1@example.com', LastName = 'Share1',
            Country = 'United States', PostalCode = '70001',
            Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        Lead l2 = new Lead(
            Company = co, Email = 'share2@example.com', LastName = 'Share2',
            Country = 'United States', PostalCode = '70001',
            Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert new List<Lead>{ l1, l2 };

        convertViaInvocable(new List<Lead>{ l1, l2 });

        List<Account> accts = [SELECT Id, (SELECT Id, Touch_Count__c FROM Opportunities) FROM Account WHERE Name = :co];
        Assert.areEqual(1, accts.size(), 'Both leads should share ONE new account, not create duplicates');
        Assert.areEqual(1, accts[0].Opportunities.size(), 'Both leads should share ONE opportunity');
        Assert.areEqual(2, accts[0].Opportunities[0].Touch_Count__c, 'Shared opp touch count should be owner + 1 follower = 2');

        List<Lead> converted = [
            SELECT IsConverted, ConvertedAccountId, ConvertedOpportunityId
            FROM Lead WHERE Id IN (:l1.Id, :l2.Id)
        ];
        Assert.areEqual(2, converted.size(), 'Both leads should be returned');
        Set<Id> acctIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        for (Lead cl : converted) {
            Assert.isTrue(cl.IsConverted, 'Both leads should convert');
            acctIds.add(cl.ConvertedAccountId);
            oppIds.add(cl.ConvertedOpportunityId);
        }
        Assert.areEqual(1, acctIds.size(), 'Both leads should converge on one account');
        Assert.areEqual(1, oppIds.size(), 'Both leads should converge on one opportunity');
    }

    @isTest
    public static void it_should_map_form_product_to_category_and_interest() {
        // Pardot delivers the real product in Form_Product__c while category/interest arrive as
        // "Not Specified". applyProductMapping() (via Pardot_Product_Mapping__mdt) must translate it
        // up front so the Lead carries the real category/interest and the opp carries Form_Product__c.
        // Relies on the org's Pardot_Product_Mapping__mdt records (3D CAD -> SOLIDWORKS 3D CAD for
        // both category and interest).
        if (Pardot_Product_Mapping__mdt.getInstance('X3D_cad') == null) {
            return; // mapping records not present in this org; skip rather than false-fail
        }
        String co = 'Zztp Mapping Co 5521';
        Lead l = new Lead(
            Company = co, Email = 'mapcat@example.com', LastName = 'MapCat',
            Country = 'United States', PostalCode = '70002',
            Lead_Product_Category__c = 'Not Specified', Lead_Product_of_Interest__c = 'Not Specified',
            Form_Product__c = '3D CAD',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [
            SELECT IsConverted, ConvertedOpportunityId, Lead_Product_Category__c, Lead_Product_of_Interest__c
            FROM Lead WHERE Id = :l.Id
        ];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual('SOLIDWORKS 3D CAD', converted.Lead_Product_Category__c,
            'Form_Product__c "3D CAD" should map the category to "SOLIDWORKS 3D CAD"');
        // POI is mapped to the same value as the category in the mdt, so the lead's incoming
        // "Not Specified" is overwritten with "SOLIDWORKS 3D CAD".
        Assert.areEqual('SOLIDWORKS 3D CAD', converted.Lead_Product_of_Interest__c,
            'POI should map to "SOLIDWORKS 3D CAD" (mdt sets POI = category)');

        Opportunity opp = [SELECT Form_Product__c FROM Opportunity WHERE Id = :converted.ConvertedOpportunityId];
        Assert.areEqual('3D CAD', opp.Form_Product__c, 'The raw form product should be carried onto the opp');
    }

    @isTest
    public static void it_should_not_collapse_different_form_products_into_one_opp() {
        // Two leads for the same brand-new company, both category "Not Specified" but different real
        // products (Form_Product__c). After mapping their categories differ, so they must NOT collapse
        // onto one opportunity -- the core of the "unrelated history" (#4) fix.
        if (Pardot_Product_Mapping__mdt.getInstance('X3D_cad') == null
                || Pardot_Product_Mapping__mdt.getInstance('J850') == null) {
            return;
        }
        String co = 'Zzwk Split Co 6643';
        Lead l1 = new Lead(
            Company = co, Email = 'split1@example.com', LastName = 'Split1',
            Country = 'United States', PostalCode = '70003',
            Lead_Product_Category__c = 'Not Specified', Lead_Product_of_Interest__c = 'Not Specified',
            Form_Product__c = '3D CAD',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        Lead l2 = new Lead(
            Company = co, Email = 'split2@example.com', LastName = 'Split2',
            Country = 'United States', PostalCode = '70003',
            Lead_Product_Category__c = 'Not Specified', Lead_Product_of_Interest__c = 'Not Specified',
            Form_Product__c = 'J850',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert new List<Lead>{ l1, l2 };

        convertViaInvocable(new List<Lead>{ l1, l2 });

        List<Account> accts = [SELECT Id, (SELECT Id FROM Opportunities) FROM Account WHERE Name = :co];
        Assert.areEqual(1, accts.size(), 'Same company should still share ONE account');
        Assert.areEqual(2, accts[0].Opportunities.size(),
            'Different real products must produce TWO opportunities, not collapse into one');
    }

    @isTest
    public static void it_should_map_training_form_value_to_training_course() {
        // The form value "Training" maps to category "Training Course" per the
        // Pardot_Product_Mapping__mdt record (verified identical in UAT and Production).
        if (Pardot_Product_Mapping__mdt.getInstance('Training') == null) {
            return;
        }
        String co = 'Zzqr Training Co 7782';
        Lead l = new Lead(
            Company = co, Email = 'train@example.com', LastName = 'Trainee',
            Country = 'United States', PostalCode = '70004',
            Lead_Product_Category__c = 'Not Specified', Lead_Product_of_Interest__c = 'Not Specified',
            Form_Product__c = 'Training',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert l;

        convertViaInvocable(new List<Lead>{ l });

        Lead converted = [SELECT IsConverted, Lead_Product_Category__c FROM Lead WHERE Id = :l.Id];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual('Training Course', converted.Lead_Product_Category__c,
            'Form value "Training" should map the category to "Training Course"');
    }

    @isTest
    public static void it_should_convert_real_production_pardot_prospects() {
        // Data-driven test seeded with 12 real prospects exported from PRODUCTION Pardot
        // (Luigi_Production_Samples.csv). It proves the full conversion pipeline behaves on the
        // shapes of data we actually receive, and -- because production does NOT yet populate
        // Form_Product__c -- it also proves applyProductMapping() is backward-compatible (no
        // Form_Product__c => leads are left untouched, categories preserved).
        //
        // Each row: { company, country, state, zip, campaignType, category, interest }.
        // Companies are real but distinct, so in a SeeAllData=false test each is treated as a
        // brand-new company: MQL/SQL => one Account + one Opportunity; UQL => Account + Contact only.
        // Limited to 10 rows so the single batch (batchSize 10) runs in ONE execute() -- a test
        // method may only trigger one executeBatch invocation.
        List<List<String>> rows = new List<List<String>>{
            new List<String>{ 'Pickering Inc.',               'USA',            'TN',               '38119',   'MQL', 'SOLIDWORKS 3D CAD',              'SOLIDWORKS 3D CAD' },
            new List<String>{ 'York University',               'Canada',         'ON',               'M3J1P3',  'MQL', 'SOLIDWORKS Simulation',          'SOLIDWORKS Simulation' },
            new List<String>{ 'Hunter Agriculture',            'United States',  'Florida',          '34711',   'SQL', '3D Printer Stratasys - Big Box', 'Not Specified' },
            new List<String>{ 'GHOST SUPPLY INC',              'Canada',         'Ontario',          'K9V4N6',  'SQL', 'Product Development',            'Product Development' },
            new List<String>{ 'FR Conversions',                '',               '',                 '21157',   'UQL', 'SOLIDWORKS PDM',                 'SOLIDWORKS PDM Professional' },
            new List<String>{ 'Lockheed Martin',               'United States',  'Georgia',          '30060',   'SQL', 'Not Specified',                  'Not Specified' },
            new List<String>{ 'MS',                            'United States',  'Washington',       '98052',   'SQL', 'Training Course',                'Training Course' },
            new List<String>{ 'Teknoware, Inc.',               'Afghanistan',    '0',                '29526',   'MQL', 'eDrawings Professional',         'eDrawings Professional' },
            new List<String>{ 'BID Canada Ltd',                'Canada',         '0',                'E3A 9X3', 'MQL', 'DraftSight',                     'Draftsight' },
            new List<String>{ 'Intercontinental Truck Body',   'Canada',         'British Columbia', 'V4N 5T4', 'SQL', '3D Scanner Artec',               'Not Specified' }
        };

        List<Lead> leads = new List<Lead>();
        Map<String, List<String>> expectedByEmail = new Map<String, List<String>>();
        Integer i = 0;
        for (List<String> row : rows) {
            String email = 'prodsample' + i + '@example.com';
            leads.add(new Lead(
                Company = row[0],
                Country = row[1],
                State = row[2],
                PostalCode = row[3],
                Campaign_Type__c = row[4],
                Lead_Product_Category__c = row[5],
                Lead_Product_of_Interest__c = row[6],
                Email = email,
                LastName = 'ProdSample' + i,
                Status = 'New'
            ));
            expectedByEmail.put(email, row);
            i++;
        }
        insert leads;

        convertViaInvocable(leads);

        List<Lead> converted = [
            SELECT Email, IsConverted, ConvertedAccountId, ConvertedOpportunityId,
                   Lead_Product_Category__c, Country, Campaign_Type__c
            FROM Lead WHERE Id IN :leads
        ];
        Assert.areEqual(rows.size(), converted.size(), 'Every seeded production lead should be returned');

        Set<Id> distinctOppIds = new Set<Id>();
        Integer expectedOppCount = 0;
        for (Lead cl : converted) {
            List<String> row = expectedByEmail.get(cl.Email);
            String company = row[0];
            String country = row[1];
            String campaignType = row[4];
            String category = row[5];

            // 1. Every production lead converts, regardless of campaign type / country / product.
            Assert.isTrue(cl.IsConverted, 'Production lead should convert: ' + company);
            Assert.isNotNull(cl.ConvertedAccountId, 'Converted lead should have an account: ' + company);

            // 2. MQL/SQL create an Opportunity; UQL does NOT (doNotCreateOpportunity).
            if (campaignType == 'UQL') {
                Assert.isNull(cl.ConvertedOpportunityId,
                    'UQL lead must not create an opportunity: ' + company);
            } else {
                Assert.isNotNull(cl.ConvertedOpportunityId,
                    campaignType + ' lead should create an opportunity: ' + company);
                distinctOppIds.add(cl.ConvertedOpportunityId);
                expectedOppCount++;
            }

            // 3. Backward-compatibility: no Form_Product__c in prod data => category is preserved
            //    exactly (applyProductMapping must be a no-op here).
            Assert.areEqual(category, cl.Lead_Product_Category__c,
                'Category must be preserved when Form_Product__c is blank: ' + company);
        }

        // 4. Each distinct new company yields its own opportunity (no accidental collapse).
        Assert.areEqual(expectedOppCount, distinctOppIds.size(),
            'Each opportunity-creating prospect should get its own distinct opportunity');

        // 5. Subsidiary routing: Canada => Javelin, everything else (incl. blank/US/other) => TriMech.
        Map<Id, Lead> leadByAccount = new Map<Id, Lead>();
        for (Lead cl : converted) {
            leadByAccount.put(cl.ConvertedAccountId, cl);
        }
        for (Account acc : [SELECT Id, Subsidiary__c FROM Account WHERE Id IN :leadByAccount.keySet()]) {
            Lead cl = leadByAccount.get(acc.Id);
            String country = (cl.Country == null) ? '' : cl.Country.toLowerCase().trim();
            Boolean isCanada = (country == 'canada' || country == 'ca' || country == 'can');
            String expectedSubsidiary = isCanada ? 'Javelin Technologies Inc.' : 'TriMech Solutions LLC';
            Assert.areEqual(expectedSubsidiary, acc.Subsidiary__c,
                'Subsidiary should match country routing for ' + expectedByEmail.get(cl.Email)[0]);
        }
    }

    @isTest
    public static void it_should_preserve_real_category_even_when_form_product_is_mapped() {
        // New guard (June 2026): applyProductMapping() must NOT override an explicitly submitted
        // Lead_Product_Category__c when the value is a real one. The category "trumps everything"
        // except when it is null or "Not Specified" -- in those cases the Form_Product__c mapping
        // is still used to fill it in. This mirrors the matching guard in
        // Pardot_Contact_Multi_Touch so the Apex and flow paths agree.
        if (Pardot_Product_Mapping__mdt.getInstance('X3D_cad') == null) {
            return; // mdt records not present in this org; skip rather than false-fail
        }
        String co = 'Zzgr Category Trumps Co 9012';
        Lead l = new Lead(
            Company = co, Email = 'cattrumps@example.com', LastName = 'CatTrumps',
            Country = 'United States', PostalCode = '70010',
            // Real explicit category + interest, with a mapped Form_Product__c that would
            // normally remap them. The guard must skip the remap.
            Lead_Product_Category__c = 'Aras Innovator',
            Lead_Product_of_Interest__c = 'Aras Innovator',
            Form_Product__c = '3D CAD',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert l;
        convertViaInvocable(new List<Lead>{ l });
        Lead converted = [
            SELECT IsConverted, ConvertedOpportunityId,
                   Lead_Product_Category__c, Lead_Product_of_Interest__c
            FROM Lead WHERE Id = :l.Id
        ];
        Assert.isTrue(converted.IsConverted, 'Lead should still convert');
        Assert.areEqual('Aras Innovator', converted.Lead_Product_Category__c,
            'Explicit category must NOT be overwritten by the Form_Product mapping');
        Assert.areEqual('Aras Innovator', converted.Lead_Product_of_Interest__c,
            'Explicit POI must NOT be overwritten by the Form_Product mapping');
        Opportunity opp = [SELECT Form_Product__c FROM Opportunity WHERE Id = :converted.ConvertedOpportunityId];
        Assert.areEqual('3D CAD', opp.Form_Product__c,
            'The raw Form_Product is still carried onto the opp, even when the category is preserved');
    }

    @isTest
    public static void it_should_preserve_real_category_when_form_product_is_unmapped() {
        // Same guard, different angle: when the Form_Product__c has NO row in the mdt and the
        // category is a real explicit value, the lead must be left fully untouched (no fall-through
        // that wipes the category to "Not Specified").
        String co = 'Zzbz Unmapped Co 9234';
        Lead l = new Lead(
            Company = co, Email = 'unmapped@example.com', LastName = 'Unmapped',
            Country = 'United States', PostalCode = '70011',
            Lead_Product_Category__c = 'CATIA',
            Lead_Product_of_Interest__c = 'CATIA',
            Form_Product__c = 'TotallyNotInTheMappingTable_XYZ_9999',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert l;
        convertViaInvocable(new List<Lead>{ l });
        Lead converted = [
            SELECT IsConverted, Lead_Product_Category__c, Lead_Product_of_Interest__c
            FROM Lead WHERE Id = :l.Id
        ];
        Assert.isTrue(converted.IsConverted, 'Lead should still convert');
        Assert.areEqual('CATIA', converted.Lead_Product_Category__c,
            'Explicit category must NOT be wiped by an unmapped Form_Product');
        Assert.areEqual('CATIA', converted.Lead_Product_of_Interest__c,
            'Explicit POI must NOT be wiped by an unmapped Form_Product');
    }

    @isTest
    public static void it_should_still_map_when_lead_category_is_blank_not_not_specified() {
        // Sanity: the guard treats null/blank as equivalent to "Not Specified". A lead with a
        // blank Lead_Product_Category__c and a mapped Form_Product__c should still be remapped.
        if (Pardot_Product_Mapping__mdt.getInstance('X3D_cad') == null) {
            return;
        }
        String co = 'Zzhf Blank Cat Co 9456';
        Lead l = new Lead(
            Company = co, Email = 'blankcat@example.com', LastName = 'BlankCat',
            Country = 'United States', PostalCode = '70012',
            Lead_Product_Category__c = null,         // blank, not "Not Specified"
            Lead_Product_of_Interest__c = null,
            Form_Product__c = '3D CAD',
            Campaign_Type__c = 'MQL', Status = 'New'
        );
        insert l;
        convertViaInvocable(new List<Lead>{ l });
        Lead converted = [
            SELECT IsConverted, Lead_Product_Category__c, Lead_Product_of_Interest__c
            FROM Lead WHERE Id = :l.Id
        ];
        Assert.isTrue(converted.IsConverted, 'Lead should convert');
        Assert.areEqual('SOLIDWORKS 3D CAD', converted.Lead_Product_Category__c,
            'A null category must still fall through to the Form_Product mapping');
        Assert.areEqual('SOLIDWORKS 3D CAD', converted.Lead_Product_of_Interest__c,
            'A null POI must still fall through to the Form_Product mapping');
    }

    /*@isTest
    public static void it_should_convert_one_unmatched_lead() {
         Lead l = new Lead(
             Company = 'Test Non Match',
             Email = 'test@example.com',
             LastName = 'Test',
             PostalCode = '12345',
             Lead_Product_Category__c = 'DraftSight',
             Lead_Product_of_Interest__c = 'DraftSight Enterprise',
             Status = 'Working'
        );

        insert l;
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.lead = l;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req};
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        System.assertEquals(fakeFlowId, resp.flowInterviewId);
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        Lead convertedLead = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id = :l.Id
        ];

        System.assertEquals(true, convertedLead.IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should be 2 Opps
        System.assertEquals(2, opps.size());
    }

    @isTest
    public static void it_should_convert_two_matching_leads() {
        Lead l1 = new Lead(
            Company = 'Test Company',
            Email = 'test1@example.com',
            LastName = 'Test1',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus'
        );

        Lead l2 = new Lead(
            Company = 'Test Company',
            Email = 'test2@example.com',
            LastName = 'Test2',
            PostalCode = '12345',
            Lead_Product_Category__c = 'DraftSight',
            Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus'
        );

        List<Lead> leads = new List<Lead>{l1, l2};
        insert leads;
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req1 = new LeadConvertInvocable.InvocationRequest();
        req1.batchSize = 10;
        req1.lead = l1;
        req1.flowInterviewId = fakeFlowId;

        LeadConvertInvocable.InvocationRequest req2 = new LeadConvertInvocable.InvocationRequest();
        req2.batchSize = 10;
        req2.lead = l2;
        req2.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req1, req2};
        // List<Lead> leads = new List<Lead>{l};
        // List<List<Lead>> leadList = new List<List<Lead>>{leads};
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 2 Response should be returned
        System.assertEquals(2, responses.size());
        
        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // Flow ID should match request
        System.assertEquals(fakeFlowId, resp.flowInterviewId);

        // LeadConvertBatch job should be created
        System.assertEquals(true, resp.leadBatched);

        AsyncApexJob batchJob = [
            SELECT  Id
            FROM    AsyncApexJob
            WHERE   Id = :resp.batchId
            LIMIT   1
        ];

        List<Lead> convertedLeads = [
            SELECT  Id,
                    IsConverted
            FROM    Lead
            WHERE   Id IN :leads
        ];

        System.assertEquals(2, convertedLeads.size());

        Lead convertedLead = convertedLeads[0];

        // Lead shuold be converted
        System.assertEquals(true, convertedLead.IsConverted);

        List<Opportunity> opps = [
            SELECT  Id
            FROM    Opportunity
        ];

        // Should only be 1 Opp still
        System.assertEquals(1, opps.size());
    }

    @isTest
    public static void it_should_return_an_error_with_no_lead(){ 
        String fakeFlowId = 'abcdefg1234';

        LeadConvertInvocable.InvocationRequest req = new LeadConvertInvocable.InvocationRequest();
        req.batchSize = 10;
        req.lead = null;
        req.flowInterviewId = fakeFlowId;

        List<LeadConvertInvocable.InvocationRequest> requests = new List<LeadConvertInvocable.InvocationRequest>{req};
    
        Test.startTest();
        List<LeadConvertInvocable.InvocationResponse> responses = LeadConvertInvocable.batchConvertLeads(requests);
        Test.stopTest();
        
        // 1 Response should be returned
        System.assertEquals(1, responses.size());

        LeadConvertInvocable.InvocationResponse resp = responses[0];

        // No lead should be batched and error message should have contents
        System.assertEquals(false, resp.leadBatched);
        System.assertNotEquals(null, resp.errorMessage);

    }*/

    // @isTest
    // public static void testMatchingLead() {
    //     Lead l = new Lead(Company = 'Test Company', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise;DraftSight Enterprise Plus');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    // }

    // @isTest
    // public static void testMatchingLeadTwo() {
    //     Lead l = new Lead(Company = 'Test Company 2', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    // }

    // @isTest
    // public static void testUQL() {
    //     Lead l = new Lead(Company = 'Test UQL', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise', Campaign_Type__c = 'UQL', Status = 'Working');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(0, opps.size());
    // }

    // @isTest
    // public static void testNonMatchingLead() {
    //     Lead l = new Lead(Company = 'Test Non Match', Email = 'test@example.com', LastName = 'Test', PostalCode = '12345', Lead_Product_Category__c = 'DraftSight', Lead_Product_of_Interest__c = 'DraftSight Enterprise', Status = 'Working');
    //     insert l;
    //     List<Lead> leads = new List<Lead>{l};
    //     List<List<Lead>> leadList = new List<List<Lead>>{leads};
    //     List<List<Id>> oppIds = LeadConvertInvocable.convertLeads(leadList);
    //     List<Opportunity> opps = [SELECT Id,StageName,CloseDate FROM Opportunity WHERE Id IN :oppIds[0]];
    //     System.assertEquals(1, opps.size());
    //     System.assertEquals('New',opps[0].StageName);
    //     System.assertEquals(Date.today().addDays(30), opps[0].CloseDate);
    // }

}