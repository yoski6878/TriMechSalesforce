trigger FeedItemTrigger on FeedItem (before insert) {
	
    for (FeedItem f : Trigger.new) {
        if (f.Body == null) continue;
        String body = f.Body.toLowerCase();

        // adjust keywords to match the exact milestone text your org generates
        if (body.contains('Updates completed') || body.contains('violation') || body.contains('Initial Response completed')  || body.contains('Completed')) {
            // optional: check parent is Case
            if (f.ParentId != null && f.ParentId.getSObjectType() == Case.sObjectType) {
                f.Visibility = 'InternalUsers'; // hide from portal/community users
            }
        }
    }    
}