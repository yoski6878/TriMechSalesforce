public with sharing class BridgeITEventHandler {
    @TestVisible private static boolean skipSessionCheck = false;
    private static boolean run = true;
    private static String workflowUser = 'BridgeIT Integration';

    public static void HandleEvent(List<SObject> newObjectList, List<SObject> oldObjectList, string triggerObjectType, string triggerType) {
        if(!skipSessionCheck) {
            String userName = 'None';

            try {
                userName = UserInfo.getName();
                System.debug('NAME ' + userName);
            }
            catch(Exception e) {
                userName = 'None';
            }
            Boolean isAPIOnlyUser = (userName == workflowUser);

            Boolean isAutomatedProcess = Test.isRunningTest() || System.isBatch() || System.isFuture()  || System.isQueueable() || System.isScheduled();
            if(!isAutomatedProcess) {
                String path = System.URL.getCurrentRequestUrl().getPath().toLowerCase();
                System.debug('PATH' + path);
                if( isAPIOnlyUser && !path.contains('aura')) {
                    return;
                }
            }
            
        }

        switch on triggerObjectType {
            when  'opportunity' {
                BridgeITOpportunityEventHandler.HandleOpportunityUpsert(newObjectList, oldObjectList, triggerType);
            }
            
            when 'account' {
                BridgeITAccountEventHandler.HandleAccountUpsert(newObjectList, oldObjectList, triggerType);
            }

            when 'contact' {
                BridgeITContactEventHandler.HandleContactUpsert(newObjectList, oldObjectList, triggerType);
            }

            when 'order' {
                BridgeITOrderEventHandler.HandleOrderUpsert(newObjectList, oldObjectList, triggerType);
            }
        }
    }

    public static boolean runOnce(){
        if(run){
            run=false;
            return true;
        }else{
            return run;
        }
    }
}