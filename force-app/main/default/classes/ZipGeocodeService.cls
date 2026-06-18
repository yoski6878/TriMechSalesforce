public with sharing class ZipGeocodeService {
    public class ZippopotamResponse {
        public List<Place> places;
    }
    public class Place {
        public String latitude;
        public String longitude;
    }

    /**
     * Looks up latitude and longitude for a given country and zipcode using Zippopotam.us API.
     * @param country Two-letter country code (e.g., 'us', 'ca')
     * @param zip Zip or postal code (no spaces for CA)
     * @return Map with keys 'latitude' and 'longitude' as Decimal, or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getLatLon(String country, String zip) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.zippopotam.us/' + country + '/' + zip);
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            ZippopotamResponse resp = (ZippopotamResponse)JSON.deserialize(res.getBody(), ZippopotamResponse.class);
            if (resp != null && resp.places != null && !resp.places.isEmpty()) {
                Place firstPlace = resp.places[0];
                Decimal lat = Decimal.valueOf(firstPlace.latitude);
                Decimal lon = Decimal.valueOf(firstPlace.longitude);
                return new Map<String, Decimal>{'latitude' => lat, 'longitude' => lon};
            }
        }
        return null;
    }
}