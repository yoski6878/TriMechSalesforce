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
	public static List<Schema.Address> getAddresses(Id accountId) {
		return [
			SELECT Id, Name, CurrencyIsoCode, ParentId, LocationType, AddressType, Street, City,
				State, PostalCode, Country, Latitude, Longitude, GeocodeAccuracy, Address, Description,
				DrivingDirections, TimeZone, Account__c, Primary_Billing_Address__c, Primary_Shipping_Address__c
			FROM Address
			WHERE Account__c = :accountId
		];
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
	public static void updateQuoteAddressesWithDetails(Id quoteId, Id billingAddressId, Id shippingAddressId) {
		Quote qt = new Quote();
		qt.Id = quoteId;

		Schema.Address billingAddr = billingAddressId != null
			? [SELECT Street, City, state, country, longitude,latitude ,PostalCode FROM Address WHERE Id = :billingAddressId LIMIT 1]
			: null;

		Schema.Address shippingAddr = shippingAddressId != null
			? [SELECT Street, City, state, country, longitude,latitude ,PostalCode  FROM Address WHERE Id = :shippingAddressId LIMIT 1]
			: null;

		if (billingAddr != null) {
			qt.BillingStreet       = billingAddr.street;
			qt.BillingCity         = billingAddr.city;
			qt.BillingState        = billingAddr.state;
			qt.BillingPostalCode   = billingAddr.postalCode;
			qt.BillingCountry      = billingAddr.country;
			qt.BillingLatitude     = billingAddr.latitude;
			qt.BillingLongitude    = billingAddr.longitude;
		}

		if (shippingAddr != null) {
			qt.ShippingStreet       = shippingAddr.street;
			qt.ShippingCity         = shippingAddr.city;
			qt.ShippingState        = shippingAddr.state;
			qt.ShippingPostalCode   = shippingAddr.postalCode;
			qt.ShippingCountry      = shippingAddr.country;
			qt.ShippingLatitude     = shippingAddr.latitude;
			qt.ShippingLongitude    = shippingAddr.longitude;
		}

		qt.AVA_SFCLOUD__Calculate_Tax__c = true;

		update qt;
	}

	@AuraEnabled
	public static void updateAccountAddressesWithDetails(Id accountId, Id billingAddressId, Id shippingAddressId) {
		Account acc = new Account();
		acc.Id = accountId;

		Schema.Address billingAddr = billingAddressId != null
			? [SELECT Street, City, state, country, longitude,latitude ,PostalCode FROM Address WHERE Id = :billingAddressId LIMIT 1]
			: null;

		Schema.Address shippingAddr = shippingAddressId != null
			? [SELECT Street, City, state, country, longitude,latitude ,PostalCode  FROM Address WHERE Id = :shippingAddressId LIMIT 1]
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

		if (shippingAddr != null) {
			acc.ShippingStreet       = shippingAddr.street;
			acc.ShippingCity         = shippingAddr.city;
			acc.ShippingState        = shippingAddr.state;
			acc.ShippingPostalCode   = shippingAddr.postalCode;
			acc.ShippingCountry      = shippingAddr.country;
			acc.ShippingLatitude     = shippingAddr.latitude;
			acc.ShippingLongitude    = shippingAddr.longitude;
		}
		update acc;
	}


}