public with sharing class BridgeITEventHandler {
    private static boolean run = true;
    
    public static void HandleEvent(List<SObject> newObjectList, List<SObject> oldObjectList, string triggerObjectType, string triggerType) {
        switch on triggerObjectType {
            when 'account' {
                BridgeITAccountEventHandler.HandleAccountUpsert(newObjectList, oldObjectList, triggerType);
            }

            when 'contact' {
                BridgeITContactEventHandler.HandleContactUpsert(newObjectList, oldObjectList, triggerType);
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