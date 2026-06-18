public class RoundRobinUtil {
    private static List<User> team;
    private static Integer idx = 0;
    private static Id fallbackJulioId;
    private static Set<Id> julioTeamIds;
    
    private static void initTeam() {
        if (team == null) {
            team = [
                SELECT Id 
                FROM User 
                WHERE (Manager.Name = 'Julio Nunez' OR Name = 'Julio Nunez')
                  AND IsActive = true
                ORDER BY Id
            ];
            julioTeamIds = new Map<Id, User>(team).keySet();
        }
        if (fallbackJulioId == null) {
            fallbackJulioId = [SELECT Id FROM User WHERE Name = 'Julio Nunez' LIMIT 1].Id;
            if (julioTeamIds == null) julioTeamIds = new Set<Id>();
            julioTeamIds.add(fallbackJulioId);
        }
        
        if(idx == null){
            RoundRobin__c cfg = RoundRobin__c.getInstance('JulioTeam');
            if(cfg == null){
                cfg = new RoundRobin__c(Name = 'JulioTeam', LastAssignedIndex__c = 0);
            }
            idx = cfg.LastAssignedIndex__c != null ? Integer.valueOf(cfg.LastAssignedIndex__c) : 0;
        }
    }
    
    public static Id getNextBDR() {
        initTeam();
        	
        if (team.isEmpty()) {
            return fallbackJulioId;
        }
        
        if (idx >= team.size()) idx = 0;
        Id nextId = team[idx].Id;
        idx++;
        return nextId;
    }
    
    public static Boolean isJulioTeamMember(Id ownerId) {
        initTeam();
        return julioTeamIds.contains(ownerId);
    }
    
    public static void persistIndex(){
        RoundRobin__c cfg = RoundRobin__c.getInstance('JulioTeam');
        if(cfg == null){
            cfg = new RoundRobin__c(Name = 'JulioTeam');
        }
        cfg.LastAssignedIndex__c = idx;
        upsert cfg;
    }
}