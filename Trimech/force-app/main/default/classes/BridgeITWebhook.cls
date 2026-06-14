@RestResource(urlMapping='/BridgeITWebhook/*')
global class BridgeITWebhook {
  public static String jsonContent(List<Object> triggerNew, List<Object> triggerOld) {
    String newObjects = '[]';
    if (triggerNew != null) {
      newObjects = JSON.serialize(triggerNew);
    }
    String oldObjects = '[]';
    if (triggerOld != null) {
      oldObjects = JSON.serialize(triggerOld);
    }
    String userId = JSON.serialize(UserInfo.getUserId());
    String content = '{"new": ' + newObjects + ', "old": ' + oldObjects + ', "userId": ' + userId + '}';
    return content;
  }

  /*
  // --- Legacy @future implementation (commented out for reference) ---
  @future(callout=true) public static void callout(String url, String content, String contextType) {
    Http h = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('X-Context-Type', contextType);
    req.setBody(content);
    IF(!test.isRunningTest()) h.send(req);
  }
  */

  // --- New Queueable implementation ---
  public class CalloutJob implements Queueable, Database.AllowsCallouts {
    private String url;
    private String content;
    private String contextType;

    public CalloutJob(String url, String content, String contextType) {
      this.url = url;
      this.content = content;
      this.contextType = contextType;
    }

    public void execute(QueueableContext context) {
      System.debug('BridgeITWebhook.CalloutJob: About to make callout to ' + url);
      System.debug('BridgeITWebhook.CalloutJob: Content length: ' + content.length());
      System.debug('BridgeITWebhook.CalloutJob: Context type: ' + contextType);
      
      Http h = new Http();
      HttpRequest req = new HttpRequest();
      req.setEndpoint(url);
      req.setMethod('POST');
      req.setHeader('Content-Type', 'application/json');
      req.setHeader('X-Context-Type', contextType);
      req.setBody(content);
      try {
        HttpResponse res = h.send(req);
        System.debug('BridgeITWebhook.CalloutJob: Callout completed. Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
      } catch (Exception e) {
        System.debug('BridgeITWebhook.CalloutJob: Callout failed with exception: ' + e.getMessage());
      }
    }
  }

  public static void callout(String url, String content, String contextType) {
    System.debug('BridgeITWebhook.callout: Enqueuing job for URL: ' + url);
    System.debug('BridgeITWebhook.callout: Content length: ' + content.length());
    System.debug('BridgeITWebhook.callout: Context type: ' + contextType);
    System.enqueueJob(new CalloutJob(url, content, contextType));
  }
}