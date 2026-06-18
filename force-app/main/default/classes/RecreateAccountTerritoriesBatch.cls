global class RecreateAccountTerritoriesBatch implements Database.Batchable<sObject> {
    
    global final String query;
    
    global RecreateAccountTerritoriesBatch(String q) {
        query = q;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        System.Debug('q : ' + query);
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Account> scope){
       RecreateAccountTerritories.doRecalculation(scope);
    }

    global void finish(Database.BatchableContext BC){
    }
}