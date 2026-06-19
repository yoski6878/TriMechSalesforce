@isTest
public class PandaDocMockCallout implements HttpCalloutMock {

    public class Config {
        public Integer code;
        public String  body;
        public Blob    bodyBlob;
        public Config(Integer c, String b) { code = c; body = b; }
        public Config(Integer c, Blob b)   { code = c; bodyBlob = b; }
    }

    private Map<String, Config> routes  = new Map<String, Config>();
    private Config              fallback;

    /**
     * Route a specific URL fragment + HTTP method to a string response.
     * Example: .route('/send', 'POST', 200, '{"status":"document.sent"}')
     */
    public PandaDocMockCallout route(String urlContains, String method, Integer code, String body) {
        routes.put(urlContains + '|' + method, new Config(code, body));
        return this;
    }

    /**
     * Route a specific URL fragment + HTTP method to a Blob response (for PDF downloads).
     */
    public PandaDocMockCallout routeBlob(String urlContains, String method, Integer code, Blob b) {
        routes.put(urlContains + '|' + method, new Config(code, b));
        return this;
    }

    /**
     * Catch-all response for any request that doesn't match a specific route.
     */
    public PandaDocMockCallout fallback(Integer code, String body) {
        this.fallback = new Config(code, body);
        return this;
    }

    public HTTPResponse respond(HTTPRequest req) {
        String ep  = req.getEndpoint();
        String mth = req.getMethod();
        Config cfg = null;

        for (String key : routes.keySet()) {
            List<String> parts = key.split('\\|');
            if (ep.contains(parts[0]) && mth == parts[1]) {
                cfg = routes.get(key);
                break;
            }
        }

        if (cfg == null) {
            cfg = fallback;
        }

        HttpResponse res = new HttpResponse();
        if (cfg != null) {
            res.setStatusCode(cfg.code);
            if (cfg.bodyBlob != null) {
                res.setBodyAsBlob(cfg.bodyBlob);
            } else {
                res.setBody(cfg.body != null ? cfg.body : '');
            }
        } else {
            res.setStatusCode(200);
            res.setBody('{}');
        }
        return res;
    }
}