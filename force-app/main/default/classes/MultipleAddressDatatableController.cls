/**
* @File Name : MultipleAddressDatatableController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : May 29, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | May 29, 2025 |   | Initial Version
**/

public class MultipleAddressDatatableController {

	public class AddressWrapper {
		@AuraEnabled public Id accountId { get; set; }
		@AuraEnabled public List<Schema.Address> addresses { get; set; }
	}

	@AuraEnabled(cacheable=true)
	public static Id getAccountIdFromQuote(String quoteId) {
		Quote qt = [SELECT AccountId FROM Quote WHERE Id = :quoteId LIMIT 1];
		return qt.AccountId;
	}

	@AuraEnabled(cacheable=true)
	public static Id getAccountIdFromOpportunity(String opportunityId) {
		Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
		return opp.AccountId;
	}

	@AuraEnabled(cacheable=true)
	public static List<Schema.Address> getAddresses(Id accountId) {
		return [
			SELECT Id, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City,
				State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description,
				DrivingDirections, TimeZone, Account__c,
				Primary_Address__c
			FROM Address
			WHERE Account__c = :accountId
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Schema.Address> getAddressesByOpportunity(Id opportunityId) {
		return [
			SELECT Id, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City,
				State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description,
				DrivingDirections, TimeZone, Account__c,
				Primary_Address__c
			FROM Address
			WHERE Lead_Opportunity__c = :opportunityId
		];
	}

	@AuraEnabled(cacheable=true)
	public static List<Schema.Address> getAddressesByProposal(Id quoteId) {
		return [
			SELECT Id, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City,
				State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description,
				DrivingDirections, TimeZone, Account__c,
				Primary_Address__c
			FROM Address
			WHERE Proposal__c = :quoteId
		];
	}

	@AuraEnabled
	public static void updateAddressDetails(Id addressId, String addressType, String street, String city, String state, String postalCode) {
		update new Schema.Address(
			Id = addressId,
			AddressType = addressType,
			Street = street,
			City = city,
			State = state,
			PostalCode = postalCode
		);
	}

	@AuraEnabled
	public static void tagAddressWithRecord(Id addressId, Id opportunityId, Id quoteId) {
		Schema.Address addr = new Schema.Address(Id = addressId);
		addr.Lead_Opportunity__c = opportunityId;
		addr.Proposal__c = quoteId;
		update addr;
	}

	// Server-side re-check of the "can't delete the Primary address" rule, so it holds
	// even if something other than this component's own UI ever calls this method.
	@AuraEnabled
	public static void deleteAddress(Id addressId) {
		Schema.Address addr = [SELECT Id, ParentId, Primary_Address__c FROM Address WHERE Id = :addressId LIMIT 1];
		if (addr.Primary_Address__c == true) {
			AuraHandledException ex = new AuraHandledException('Please select another Primary address before deleting this one.');
			ex.setMessage('Please select another Primary address before deleting this one.');
			throw ex;
		}

		Id locationId = addr.ParentId;
		delete addr;

		if (locationId != null) {
			List<Schema.Location> autoLocations = [
				SELECT Id FROM Location WHERE Id = :locationId AND Name = 'Auto Generated Location'
			];
			if (!autoLocations.isEmpty()) {
				delete autoLocations;
			}
		}
	}

	// Primary is a single, Account-wide designation: setting it here clears the flag on every
	// address tied to this Account - not just the ones visible in whichever Opportunity/Proposal
	// scope triggered the change - and cascades the resulting Billing Address to the Account and
	// every Quote under it, so Account, Opportunity, and Proposal views always agree.
	@AuraEnabled
	public static void setPrimaryAddress(Id primaryAddressId, Id accountId) {
		List<Schema.Address> accountAddresses = [
			SELECT Id FROM Address WHERE Account__c = :accountId
		];
		List<Schema.Address> addressesToUpdate = new List<Schema.Address>();
		for (Schema.Address addr : accountAddresses) {
			addressesToUpdate.add(new Schema.Address(
				Id = addr.Id,
				Primary_Address__c = (addr.Id == primaryAddressId)
			));
		}
		update addressesToUpdate;

		updateAccountAddressesWithDetails(accountId, primaryAddressId);

		Schema.Address primaryAddr = [
			SELECT Street, City, State, Country, Latitude, Longitude, PostalCode
			FROM Address
			WHERE Id = :primaryAddressId
			LIMIT 1
		];

		List<Quote> quotesToUpdate = new List<Quote>();
		for (Quote qt : [SELECT Id FROM Quote WHERE AccountId = :accountId]) {
			quotesToUpdate.add(new Quote(
				Id = qt.Id,
				BillingStreet = primaryAddr.Street,
				BillingCity = primaryAddr.City,
				BillingState = primaryAddr.State,
				BillingPostalCode = primaryAddr.PostalCode,
				BillingCountry = primaryAddr.Country,
				BillingLatitude = primaryAddr.Latitude,
				BillingLongitude = primaryAddr.Longitude,
				AVA_SFCLOUD__Calculate_Tax__c = true
			));
		}
		if (!quotesToUpdate.isEmpty()) {
			update quotesToUpdate;
		}
	}

	// @AuraEnabled(cacheable=true)
	// public static AddressWrapper getAddresses(string recordId) {
	// 	Quote qt = [SELECT AccountId FROM Quote WHERE Id = :recordId LIMIT 1];

	// 	List<Schema.Address> addresses = [
	// 		SELECT Id, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City,
	// 			State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description,
	// 			DrivingDirections, TimeZone, Account__c, Primary_Billing_Address__c, Primary_Shipping_Address__c
	// 		FROM Address
	// 		WHERE Account__c = :qt.AccountId
	// 	];

	// 	AddressWrapper wrapper = new AddressWrapper();
	// 	wrapper.accountId = qt.AccountId;
	// 	wrapper.addresses = addresses;

	// 	return wrapper;
	// }

	@AuraEnabled
	public static void updateAccountAddressesWithDetails(Id accountId, Id billingAddressId) {
		Account acc = new Account();
		acc.Id = accountId;

		Schema.Address billingAddr = billingAddressId != null
			? [SELECT Street, City, state, country, longitude,latitude ,PostalCode FROM Address WHERE Id = :billingAddressId LIMIT 1]
			: null;

		if (billingAddr != null) {
			acc.BillingStreet       = billingAddr.street;
			acc.BillingCity         = billingAddr.city;
			acc.BillingState        = billingAddr.state;
			acc.BillingPostalCode   = billingAddr.postalCode;
			acc.BillingCountry      = billingAddr.country;
			acc.BillingLatitude     = billingAddr.latitude;
			acc.BillingLongitude    = billingAddr.longitude;
		}
		update acc;
	}


}