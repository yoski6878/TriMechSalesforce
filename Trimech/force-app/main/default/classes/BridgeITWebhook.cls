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
  @future(callout=true) public static void callout(String url, String content, string contextType) {
    Http h = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('X-Context-Type', contextType);
    req.setBody(content);
    if (!Test.isRunningTest()) h.send(req);
  }
}