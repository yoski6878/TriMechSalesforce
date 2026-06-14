public with sharing class BridgeITOpportunityEventHandler {

    public static void HandleOpportunityUpsert(
        List<Opportunity> newOpportunityList,
        List<Opportunity> oldOpportunityList,
        String triggerType
    ) {
        for (Opportunity newOpp : newOpportunityList) {

            // Only process when Opportunity reaches OM stage
            if (newOpp.StageName != 'Send to Order Management') {
                continue;
            }

            // Do not resubmit opportunities that are already linked to a NetSuite order.
            if (!String.isBlank(newOpp.celigo_sfnsio__NetSuite_Id__c)) {
                continue;
            }
            Opportunity opportunity = getOpportunityById(newOpp.Id);
            if (opportunity == null) {
                continue;
            }


            /* -----------------------------
             * Opportunity payload
             * ----------------------------- */
            Map<String, Object> oppPayload =
                (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(opportunity));

            /* -----------------------------
             * Scheduling Contact enrichment
             * ----------------------------- */
            if (opportunity.Scheduling_Contact__c != null) {
                Contact schedulingContact = [
                    SELECT Id, celigo_sfnsio__NetSuite_Id__c
                    FROM Contact
                    WHERE Id = :opportunity.Scheduling_Contact__c
                    LIMIT 1
                ];

                // Always include SF Contact Id
                oppPayload.put('Scheduling_Contact__c', opportunity.Scheduling_Contact__c);

                // Include NetSuite Id if present
                oppPayload.put(
                    'SchedulingContactNetSuiteId',
                    String.isBlank(schedulingContact.celigo_sfnsio__NetSuite_Id__c)
                        ? null
                        : schedulingContact.celigo_sfnsio__NetSuite_Id__c
                );
            }

            /* -----------------------------
             * Opportunity owner
             * ----------------------------- */
            User owner = null;
            List<User> owners = [
                SELECT Id, Name, Email, Division, Department, NetSuite_Internal_Id_IO__c
                FROM User
                WHERE Id = :newOpp.OwnerId
                LIMIT 1
            ];
            owner = owners.isEmpty() ? null : owners[0];

            /* -----------------------------
             * Opportunity line items
             * ----------------------------- */
            List<OpportunityLineItem> opportunityLineItems = [
                SELECT
                    Id,
                    Quantity,
                    UnitPrice,
                    Discount,
                    SortOrder,
                    Line_Description__c,
                    Commission__c,
                    Product2.celigo_sfnsio__NetSuite_Id__c
                FROM OpportunityLineItem
                WHERE OpportunityId = :newOpp.Id
            ];

            /* -----------------------------
             * Account & primary contact
             * ----------------------------- */
            Account account = getAccountById(newOpp.AccountId);
            Contact primaryContact = getContactById(newOpp.Primary_Contact__c);

            /* -----------------------------
             * Opportunity splits (non-revenue)
             * ----------------------------- */
            List<OpportunitySplit> opportunitySplits = [
                SELECT
                    Id,
                    SplitOwnerId,
                    SplitPercentage,
                    SplitAmount,
                    Split_Owner_NetSuite_Id__c,
                    SplitTypeId
                FROM OpportunitySplit
                WHERE OpportunityId = :newOpp.Id
                  AND IsDeleted = false
                  AND SplitTypeId != '1494V00000009uuQAA' // Revenue split
            ];

            /* -----------------------------
             * Notes & enhanced notes
             * ----------------------------- */
            List<Note> notes = [
                SELECT Id, Title, Body, CreatedDate, CreatedById
                FROM Note
                WHERE ParentId = :newOpp.Id
                  AND IsDeleted = false
            ];

            List<ContentDocumentLink> enhancedNotes = [
                SELECT
                    ContentDocument.Title,
                    ContentDocument.LatestPublishedVersion.VersionData
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :newOpp.Id
                  AND ContentDocument.FileType = 'SNOTE'
            ];

            /* -----------------------------
             * Account contacts without NetSuite Id
             * ----------------------------- */
            List<Contact> contactsWithoutNetSuiteId = new List<Contact>();

            if (newOpp.AccountId != null) {
                contactsWithoutNetSuiteId = [
                    SELECT
                        Id,
                        Account_Subsidiary__c,
                        celigo_sfnsio__NetSuite_Id__c,
                        Inactive__c,
                        Salutation,
                        FirstName,
                        MiddleName,
                        LastName,
                        Goes_By__c,
                        Email,
                        Phone,
                        MobilePhone,
                        Office_Phone__c,
                        Department,
                        Fax,
                        Title,
                        General_Comments__c,
                        LinkedIn__c,
                        Contact_Type__c,
                        DoNotCall,
                        MailingStreet,
                        MailingCity,
                        MailingState,
                        MailingPostalCode,
                        MailingCountry,
                        HasOptedOutOfEmail
                    FROM Contact
                    WHERE AccountId = :newOpp.AccountId
                    AND IsDeleted = false
                    AND Id != :newOpp.Primary_Contact__c
                    AND celigo_sfnsio__NetSuite_Id__c = null
                    AND NetSuite_Id__c = null
                ];

                // Touch fields so nulls are serialized (aligned to getContactById / OpportunityWebhookContact)
                touchContactsForSerialization(contactsWithoutNetSuiteId);
            }

            /* -----------------------------
             * Final webhook payload
             * ----------------------------- */
            Map<String, Object> oppToSend = new Map<String, Object>{
                'opportunity'                      => oppPayload,
                'opportunityOwner'                 => owner,
                'opportunityLineItems'             => opportunityLineItems,
                'opportunitySplits'                => opportunitySplits,
                'notes'                            => notes,
                'enhancedNotes'                    => enhancedNotes,
                'account'                          => account,
                'contact'                          => primaryContact,
                'accountContactsWithoutNetSuiteId' => contactsWithoutNetSuiteId
            };

            String url     = System.label.BridgeIT_Webhook_Opportunity_Logic_App_Url;
            String userId  = JSON.serialize(UserInfo.getUserId());

            BridgeITWebhook.callout(url, JSON.serialize(oppToSend), triggerType);

            Account acc = new Account(
                Id = newOpp.AccountId, 
                Status__c = 'CLIENT-(100%) Won'
            );
            update acc;
        }
    }

    private static Opportunity getOpportunityById(Id opportunityId) {
        if (opportunityId == null) return null;

        List<Opportunity> rows = [
            SELECT
                Id,
                Pricebook2Id,
                Type,
                Primary_Contact_NetSuite_Id_IO__c,
                Terms__c,
                End_User_Department__c,
                Needs_GP_Adjustment__c,
                CHIT_Info__c,
                Training_on_PO__c,
                Piracy__c,
                Order_Management_Note__c,
                SSYS_Salesforce_Proposal_Number__c,
                Delivery_Requirements__c,
                Dock_Hours__c,
                CurrencyIsoCode,
                SolidProfessor_Contact_NetSuite_ID_IO__c,
                Inside_Sales__c,
                Inside_Sales_Rep_NetSuite_ID__c,
                Summary_Description_of_Order__c,
                Payment_Type__c,
                Contact_for_Payment_Netsuite_ID__c,
                Forms__c,
                Additional_Notes__c,
                Is_software_on_this_order__c,
                End_User_Netsuite_Ids__c,
                Site_ID__c,
                CLOSA_Contact_Netsuite_ID__c,
                Product_Type_Coupon_Code_Percentage__c,
                Changing_or_Adding_to_Existing_License__c,
                Provide_current_SN_we_are_adjusting__c,
                Tenant__c,
                Coterming_to_Existing_Assets__c,
                Coterming_to_what_date__c,
                Case_ID__c,
                Does_this_order_require_ITAR_Compliance__c,
                ACR__c,
                Corp_credits_or_closed_training_on_order__c,
                Passport_Owner_Netsuite_Ids__c,
                Is_student_already_enrolled_as_unpaid__c,
                Course_Name__c,
                Course_Date__c,
                Digital_or_in_person_location_pl__c,
                Student_Netsuite_Ids__c,
                Are_there_additional_courses__c,
                Are_services_products_on_this_order__c,
                Are_hardware_products_on_this_order__c,
                End_User_Names_hardware__c,
                Trade_in_Serial_Number__c,
                Shipping_Contact_Netsuite_ID__c,
                Lift_Gate_or_Pallet_Jack_required__c,
                Vendor_Pricing_Details__c,
                End_User_Netsuite_Ids_hardware__c,
                Discount_on_Order__c,
                In_Person_Location__c,
                Scheduling_Contact__c,
                Territory_Sales_Rep_NetSuite_Id__c,
                Sales_Rep_Location__c,
                End_User_Ids__c,
                End_User_Ids_hardware__c,
                Passport_Owner_Ids__c,
                Student_Ids__c,
                CLOSA_Contact__c,
                SolidProfessor_Contact__c,
                Shipping_Contact__c,
                Contact_for_Payment_AP__c,
                celigo_sfnsio__Skip_Export_To_NetSuite__c,
                Referral_Source__c,
                Employee_Referral_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (rows.isEmpty()) return null;

        Opportunity o = rows[0];

        // Touch fields so nulls are serialized
        o.Pricebook2Id                            = o.Pricebook2Id;
        o.Terms__c                                = o.Terms__c;
        o.End_User_Department__c                  = o.End_User_Department__c;
        o.Needs_GP_Adjustment__c                  = o.Needs_GP_Adjustment__c;
        o.CHIT_Info__c                            = o.CHIT_Info__c;
        o.Training_on_PO__c                       = o.Training_on_PO__c;
        o.Piracy__c                               = o.Piracy__c;
        o.Order_Management_Note__c                = o.Order_Management_Note__c;
        o.SSYS_Salesforce_Proposal_Number__c      = o.SSYS_Salesforce_Proposal_Number__c;
        o.Delivery_Requirements__c                = o.Delivery_Requirements__c;
        o.Dock_Hours__c                           = o.Dock_Hours__c;
        o.CurrencyIsoCode                         = o.CurrencyIsoCode;
        o.Inside_Sales__c                         = o.Inside_Sales__c;
        o.Summary_Description_of_Order__c         = o.Summary_Description_of_Order__c;
        o.Payment_Type__c                         = o.Payment_Type__c;
        o.Forms__c                                = o.Forms__c;
        o.Additional_Notes__c                     = o.Additional_Notes__c;
        o.Is_software_on_this_order__c            = o.Is_software_on_this_order__c;
        o.End_User_Netsuite_Ids__c                = o.End_User_Netsuite_Ids__c;
        o.Site_ID__c                              = o.Site_ID__c;
        o.Product_Type_Coupon_Code_Percentage__c  = o.Product_Type_Coupon_Code_Percentage__c;
        o.Changing_or_Adding_to_Existing_License__c = o.Changing_or_Adding_to_Existing_License__c;
        o.Provide_current_SN_we_are_adjusting__c   = o.Provide_current_SN_we_are_adjusting__c;
        o.Tenant__c                               = o.Tenant__c;
        o.Coterming_to_Existing_Assets__c         = o.Coterming_to_Existing_Assets__c;
        o.Coterming_to_what_date__c               = o.Coterming_to_what_date__c;
        o.Case_ID__c                              = o.Case_ID__c;
        o.Does_this_order_require_ITAR_Compliance__c = o.Does_this_order_require_ITAR_Compliance__c;
        o.ACR__c                                  = o.ACR__c;
        o.Corp_credits_or_closed_training_on_order__c = o.Corp_credits_or_closed_training_on_order__c;
        o.Passport_Owner_Netsuite_Ids__c           = o.Passport_Owner_Netsuite_Ids__c;
        o.Is_student_already_enrolled_as_unpaid__c = o.Is_student_already_enrolled_as_unpaid__c;
        o.Course_Name__c                          = o.Course_Name__c;
        o.Course_Date__c                          = o.Course_Date__c;
        o.Digital_or_in_person_location_pl__c     = o.Digital_or_in_person_location_pl__c;
        o.Student_Netsuite_Ids__c                  = o.Student_Netsuite_Ids__c;
        o.Are_there_additional_courses__c          = o.Are_there_additional_courses__c;
        o.Are_services_products_on_this_order__c   = o.Are_services_products_on_this_order__c;
        o.Are_hardware_products_on_this_order__c   = o.Are_hardware_products_on_this_order__c;
        o.End_User_Names_hardware__c               = o.End_User_Names_hardware__c;
        o.Trade_in_Serial_Number__c                = o.Trade_in_Serial_Number__c;
        o.Lift_Gate_or_Pallet_Jack_required__c     = o.Lift_Gate_or_Pallet_Jack_required__c;
        o.Vendor_Pricing_Details__c                = o.Vendor_Pricing_Details__c;
        o.End_User_Netsuite_Ids_hardware__c        = o.End_User_Netsuite_Ids_hardware__c;
        o.Discount_on_Order__c                     = o.Discount_on_Order__c;
        o.In_Person_Location__c                    = o.In_Person_Location__c;
        o.Scheduling_Contact__c                    = o.Scheduling_Contact__c;
        o.Type                                     = o.Type;
        o.CLOSA_Contact__c                         = o.CLOSA_Contact__c;
        o.SolidProfessor_Contact__c                = o.SolidProfessor_Contact__c;
        o.Shipping_Contact__c                      = o.Shipping_Contact__c;
        o.Contact_for_Payment_AP__c                = o.Contact_for_Payment_AP__c;
        o.celigo_sfnsio__Skip_Export_To_NetSuite__c = o.celigo_sfnsio__Skip_Export_To_NetSuite__c;
        o.Referral_Source__c                       = o.Referral_Source__c;
        o.Employee_Referral_Name__c                = o.Employee_Referral_Name__c;

        return o;
    }

    private static Contact getContactById(Id contactId) {
        if (contactId == null) return null;

        List<Contact> rows = [
            SELECT
                Id,
                Account_Subsidiary__c,
                celigo_sfnsio__NetSuite_Id__c,
                Inactive__c,
                Salutation,
                FirstName,
                MiddleName,
                LastName,
                Goes_By__c,
                Email,
                Phone,
                MobilePhone,
                Office_Phone__c,
                Department,
                Fax,
                Title,
                General_Comments__c,
                LinkedIn__c,
                Contact_Type__c,
                DoNotCall,
                MailingStreet,
                MailingCity,
                MailingState,
                MailingPostalCode,
                MailingCountry,
                HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :contactId
              AND IsDeleted = false
            LIMIT 1
        ];

        if (rows.isEmpty()) return null;

        Contact c = rows[0];

        // Touch fields so nulls are serialized (aligned to OpportunityWebhookContact)
        touchContactForSerialization(c);

        return c;
    }

    private static Account getAccountById(Id accountId) {
        if (accountId == null) return null;

        Account account = [
            SELECT
                Id,
                celigo_sfnsio__NetSuite_Id__c,
                celigo_sfnsio__Credit_Hold__c,
                celigo_sfnsio__Credit_Limit__c,
                Credit_Hold_Status__c,
                celigo_sfnsio__Days_Overdue__c,
                Name,
                ParentId,
                Phone,
                Description,
                Fax,
                Website,
                Industry,
                Client_End_Market__c,
                Government_Classification__c,
                Direct_Indirect_Orders__c,
                Email__c,
                Dedicated_Account__c,
                Dedicated_Hardware__c,
                Inside_Sales_Dedicated_Account__c,
                Sales_Rep_Enterprise__c,
                Inactive__c,
                Territory__c,
                Region__c,
                Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Sales_Rep_Hardware__r.NetSuite_Internal_Id_IO__c,
                Dedicated_Enterprise_Rep__r.NetSuite_Internal_Id_IO__c,
                Software_Sales_Person_NS_Id__c,
                Hardware_Sales_Person_NS_Id__c,
                Enterprise_Sales_Person_NS_Id__c,
                Subsidiary__c,
                CurrencyIsoCode,
                Client_Engagement_Rep__r.NetSuite_Internal_Id_IO__c,
                Sales_Rep_Enterprise__r.NetSuite_Internal_Id_IO__c,
                Account_Type__c,
                Type,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                BillingLatitude,
                BillingLongitude,
                BillingGeocodeAccuracy,
                ShippingStreet,
                ShippingCity,
                ShippingState,
                ShippingPostalCode,
                ShippingCountry,
                ShippingLatitude,
                ShippingLongitude,
                ShippingGeocodeAccuracy,
                MSA_Expiry_Date__c,
                MSA_on_File__c,
                Acquired_From__c,
                Dsx_Site_ID__c,
                AVA_MAPPER__Exemption_Number__c,
                External_ID__c,
                celigo_sfnsio__Skip_Export_To_NetSuite__c,
                Sales_Rep_Hardware_Outside__r.NetSuite_Internal_Id_IO__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        // Touch scalar fields so nulls are serialized
        account.Id                                     = account.Id;
        account.celigo_sfnsio__NetSuite_Id__c           = account.celigo_sfnsio__NetSuite_Id__c;
        account.celigo_sfnsio__Credit_Hold__c           = account.celigo_sfnsio__Credit_Hold__c;
        account.celigo_sfnsio__Credit_Limit__c          = account.celigo_sfnsio__Credit_Limit__c;
        account.celigo_sfnsio__Days_Overdue__c          = account.celigo_sfnsio__Days_Overdue__c;


        account.Name                                   = account.Name;
        account.ParentId                               = account.ParentId;
        account.Phone                                  = account.Phone;
        account.Description                            = account.Description;
        account.Fax                                    = account.Fax;
        account.Website                                = account.Website;
        account.Industry                               = account.Industry;
        account.Client_End_Market__c                   = account.Client_End_Market__c;
        account.Government_Classification__c           = account.Government_Classification__c;
        account.Direct_Indirect_Orders__c              = account.Direct_Indirect_Orders__c;
        account.Email__c                               = account.Email__c;

        account.Dedicated_Account__c                   = account.Dedicated_Account__c;
        account.Dedicated_Hardware__c                  = account.Dedicated_Hardware__c;
        account.Inside_Sales_Dedicated_Account__c      = account.Inside_Sales_Dedicated_Account__c;
        account.Inactive__c                            = account.Inactive__c;

        account.Territory__c                           = account.Territory__c;
        account.Region__c                              = account.Region__c;
        account.Subsidiary__c                          = account.Subsidiary__c;
        account.CurrencyIsoCode                        = account.CurrencyIsoCode;
        account.Account_Type__c                        = account.Account_Type__c;
        account.Type                                   = account.Type;

        account.BillingStreet                          = account.BillingStreet;
        account.BillingCity                            = account.BillingCity;
        account.BillingState                           = account.BillingState;
        account.BillingPostalCode                      = account.BillingPostalCode;
        account.BillingCountry                         = account.BillingCountry;
        account.BillingLatitude                        = account.BillingLatitude;
        account.BillingLongitude                       = account.BillingLongitude;
        account.BillingGeocodeAccuracy                 = account.BillingGeocodeAccuracy;

        account.ShippingStreet                         = account.ShippingStreet;
        account.ShippingCity                           = account.ShippingCity;
        account.ShippingState                          = account.ShippingState;
        account.ShippingPostalCode                     = account.ShippingPostalCode;
        account.ShippingCountry                        = account.ShippingCountry;
        account.ShippingLatitude                       = account.ShippingLatitude;
        account.ShippingLongitude                      = account.ShippingLongitude;
        account.ShippingGeocodeAccuracy                = account.ShippingGeocodeAccuracy;

        account.MSA_Expiry_Date__c                     = account.MSA_Expiry_Date__c;
        account.MSA_on_File__c                         = account.MSA_on_File__c;
        account.Acquired_From__c                       = account.Acquired_From__c;
        account.Dsx_Site_ID__c                         = account.Dsx_Site_ID__c;
        account.AVA_MAPPER__Exemption_Number__c        = account.AVA_MAPPER__Exemption_Number__c;
        account.External_ID__c                         = account.External_ID__c;

        account.celigo_sfnsio__Skip_Export_To_NetSuite__c =
            account.celigo_sfnsio__Skip_Export_To_NetSuite__c;

        // Touch related fields only if the child SObject is present.
        if (account.Sales_Rep_Software__r != null) {
            account.Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c =
                account.Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c;
        }
        if (account.Dedicated_Sales_Rep_Hardware__r != null) {
            account.Dedicated_Sales_Rep_Hardware__r.NetSuite_Internal_Id_IO__c =
                account.Dedicated_Sales_Rep_Hardware__r.NetSuite_Internal_Id_IO__c;
        }
        if (account.Client_Engagement_Rep__r != null) {
            account.Client_Engagement_Rep__r.NetSuite_Internal_Id_IO__c =
                account.Client_Engagement_Rep__r.NetSuite_Internal_Id_IO__c;
        }
        
        if (account.Sales_Rep_Enterprise__r != null) {
            account.Sales_Rep_Enterprise__r.NetSuite_Internal_Id_IO__c =
                account.Sales_Rep_Enterprise__r.NetSuite_Internal_Id_IO__c;
        }
        if(account.Dedicated_Sales_Rep_Software__r != null) {
            account.Dedicated_Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c =
                account.Dedicated_Sales_Rep_Software__r.NetSuite_Internal_Id_IO__c;
        }

        if(account.Dedicated_Enterprise_Rep__r != null) {
            account.Dedicated_Enterprise_Rep__r.NetSuite_Internal_Id_IO__c =
                account.Dedicated_Enterprise_Rep__r.NetSuite_Internal_Id_IO__c;
        }

        return account;
    }

    /* ------------------------------------------
     * Helpers: touch fields for serialization
     * ------------------------------------------ */

    private static void touchContactsForSerialization(List<Contact> contacts) {
        if (contacts == null) return;
        for (Contact c : contacts) {
            touchContactForSerialization(c);
        }
    }

    private static void touchContactForSerialization(Contact c) {
        if (c == null) return;

        c.Id                           = c.Id;
        c.celigo_sfnsio__NetSuite_Id__c = c.celigo_sfnsio__NetSuite_Id__c;

        c.Inactive__c                  = c.Inactive__c;
        c.Salutation                   = c.Salutation;
        c.FirstName                    = c.FirstName;
        c.MiddleName                   = c.MiddleName;
        c.LastName                     = c.LastName;
        c.Goes_By__c                   = c.Goes_By__c;

        c.Email                        = c.Email;
        c.Phone                        = c.Phone;
        c.MobilePhone                  = c.MobilePhone;
        c.Office_Phone__c              = c.Office_Phone__c;
        c.Department                   = c.Department;
        c.Fax                          = c.Fax;
        c.Title                        = c.Title;

        c.General_Comments__c          = c.General_Comments__c;
        c.LinkedIn__c                  = c.LinkedIn__c;
        c.Contact_Type__c              = c.Contact_Type__c;
        c.DoNotCall                    = c.DoNotCall;

        c.MailingStreet                = c.MailingStreet;
        c.MailingCity                  = c.MailingCity;
        c.MailingState                 = c.MailingState;
        c.MailingPostalCode            = c.MailingPostalCode;
        c.MailingCountry               = c.MailingCountry;
    }
}