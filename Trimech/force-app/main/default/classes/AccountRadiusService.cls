public with sharing class AccountRadiusService {

    public class RadiusInput {
        @InvocableVariable(label='Zipcode' required=true)
        public String zipcode;
        @InvocableVariable(label='Radius (miles)' required=true)
        public Decimal radiusMiles;
    }

    public class RadiusResult {
        @InvocableVariable public Boolean foundZip;
        @InvocableVariable public String message;
        @InvocableVariable public List<Account> accounts;
        @InvocableVariable public Decimal latitude;
        @InvocableVariable public Decimal longitude;
        @InvocableVariable public String csv;
        public RadiusResult(Boolean foundZip, String message, List<Account> accounts, Decimal latitude, Decimal longitude, String csv) {
            this.foundZip = foundZip;
            this.message = message;
            this.accounts = accounts;
            this.latitude = latitude;
            this.longitude = longitude;
            this.csv = csv;
        }
        public RadiusResult(Boolean foundZip, String message, List<Account> accounts) {
            this(foundZip, message, accounts, null, null, null);
        }
    }
    /**
     * Returns Account records within a specified radius (in miles) of a given latitude/longitude.
     * Bulk-safe, governor-limit aware.
     *
     * Input: latitude, longitude, radiusMiles (all required)
     * Output: List of Account records within the radius
     */

    /**
     * Haversine formula for distance between two lat/lon points (miles).
     */
    public static Decimal calculateDistanceMiles(
        Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2
    ) {
        // Convert degrees to radians manually
        Double rlat1 = ((Double)lat1) * Math.PI / 180;
        Double rlon1 = ((Double)lon1) * Math.PI / 180;
        Double rlat2 = ((Double)lat2) * Math.PI / 180;
        Double rlon2 = ((Double)lon2) * Math.PI / 180;

        Double dlat = rlat2 - rlat1;
        Double dlon = rlon2 - rlon1;

        Double a = Math.sin(dlat/2) * Math.sin(dlat/2) +
                   Math.cos(rlat1) * Math.cos(rlat2) *
                   Math.sin(dlon/2) * Math.sin(dlon/2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        Double earthRadiusMiles = 3958.8;
        return Decimal.valueOf(earthRadiusMiles * c);
    }
    /**
     * Flow-invocable method: Returns Account records within a specified radius (in miles) of the provided latitude/longitude.
     * Uses SOQL DISTANCE for efficient geospatial querying.
     *
     * @param inputs List of RadiusInput (latitude, longitude, radiusMiles)
     * @return List of RadiusResult (foundZip, message, accounts)
     */
    @InvocableMethod(label='Get Accounts Within Radius By Lat/Lon')
    public static List<RadiusResult> getAccountsWithinRadiusByZip(List<RadiusInput> inputs) {
        List<RadiusResult> results = new List<RadiusResult>();
        for (RadiusInput input : inputs) {
            // Detect country and normalize postal code
            String normalizedZip = input.zipcode != null ? input.zipcode.replace(' ', '').toUpperCase() : '';
            String country = 'us';
            // US ZIP: 5 digits
            Boolean isUS = false;
            if (normalizedZip.length() == 5) {
                isUS = true;
                for (Integer i = 0; i < 5; i++) {
                    String c = normalizedZip.substring(i, i+1);
                    if (!'0123456789'.contains(c)) {
                        isUS = false;
                        break;
                    }
                }
            }
            // Canadian Postal: first 3 chars A9A
            Boolean isCanadian = false;
            if (normalizedZip.length() >= 3) {
                String c0 = normalizedZip.substring(0,1);
                String c1 = normalizedZip.substring(1,2);
                String c2 = normalizedZip.substring(2,3);
                isCanadian =
                    c0 >= 'A' && c0 <= 'Z' &&
                    '0123456789'.contains(c1) &&
                    c2 >= 'A' && c2 <= 'Z';
            }
            if (isCanadian) {
                country = 'ca';
            }
            String lookupZip = normalizedZip;
            if (isCanadian && normalizedZip.length() >= 3) {
                lookupZip = normalizedZip.substring(0, 3);
            }
            Map<String, Decimal> latLon = ZipGeocodeService.getLatLon(country, lookupZip);
            if (latLon == null || !latLon.containsKey('latitude') || !latLon.containsKey('longitude')) {
                results.add(new RadiusResult(false, 'Could not geocode zipcode: ' + input.zipcode, new List<Account>(), null, null, null));
                continue;
            }
            Decimal centerLat = latLon.get('latitude');
            Decimal centerLon = latLon.get('longitude');
            // Use SOQL DISTANCE function to fetch Accounts within the radius
            List<Account> result = [
                SELECT Id, Name, ShippingLatitude, ShippingLongitude, ShippingPostalCode, Territory__c, ShippingCity, ShippingState
                FROM Account
                WHERE ShippingLatitude != null AND ShippingLongitude != null
                  AND DISTANCE(ShippingAddress, GEOLOCATION(:centerLat, :centerLon), 'mi') < :input.radiusMiles
                LIMIT 1000
            ];
            // Generate CSV string
            String csv = generateAccountCsv(result);
            results.add(new RadiusResult(true, 'Success', result, centerLat, centerLon, csv));
        }
        return results;
    }

    // Generate CSV string from Account list
    private static String generateAccountCsv(List<Account> accounts) {
        List<String> lines = new List<String>();
        lines.add('Id,Name,ShippingPostalCode,Territory__c,ShippingCity,ShippingState');
        for (Account acc : accounts) {
            List<String> row = new List<String>{
                escapeCsv(String.valueOf(acc.Id)),
                escapeCsv(acc.Name),
                escapeCsv(acc.ShippingPostalCode),
                escapeCsv(String.valueOf(acc.get('Territory__c'))),
                escapeCsv(acc.ShippingCity),
                escapeCsv(acc.ShippingState)
            };
            lines.add(String.join(row, ','));
        }
        return String.join(lines, '\n');
    }

    // Escape CSV values (handles commas, quotes, newlines)
    private static String escapeCsv(String val) {
        if (val == null) return '';
        Boolean needsQuotes = val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r');
        String out = val.replace('"', '""');
        if (needsQuotes) {
            out = '"' + out + '"';
        }
        return out;
    }
}