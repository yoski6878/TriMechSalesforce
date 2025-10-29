global class NeglectedLeadOppReassignmentBatch
implements Database.Batchable<SObject>, Database.Stateful {

    // Cached across the batch (Stateful)
    private List<Id> teamOrder = new List<Id>();
    private Set<Id> teamIds = new Set<Id>();

    public NeglectedLeadOppReassignmentBatch() {}

    public Database.QueryLocator start(Database.BatchableContext bc) {
    
        List<User> team = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND (Manager.Name = 'Julio Nunez' OR Name = 'Julio Nunez')
            ORDER BY Name
        ];
        for (User u : team) {
            teamOrder.add(u.Id);
            teamIds.add(u.Id);
        }
        
        if(Test.isRunningTest()){
             return Database.getQueryLocator([
                 SELECT Id, OwnerId, RecordType.DeveloperName, StageName,
                       ProductGroup_Name__c, CloseDate, LastModifiedDate,
                       Neglected_Date__c, LSC_Campaign__c, Days_Since_Last_Activity__c,
                       IsClosed
                FROM Opportunity
             ]);
        }

        return Database.getQueryLocator([
            SELECT Id, OwnerId, RecordType.DeveloperName, StageName,
                   ProductGroup_Name__c, CloseDate, LastModifiedDate,
                   Neglected_Date__c, LSC_Campaign__c, Days_Since_Last_Activity__c,
                   IsClosed
            FROM Opportunity
            WHERE ProductGroup_Name__c IN ('Hardware','AMS')
              AND IsClosed = false
              AND OwnerId NOT IN :teamIds ]);

    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        if (teamOrder.isEmpty()) {
            return;
        }

        RoundRobin__c cfg = null;
        Integer lastIdx = -1;
        List<RoundRobin__c> rows = [
            SELECT Id, Name, LastAssignedIndex__c
            FROM RoundRobin__c
            WHERE Name = 'JulioTeam'
            LIMIT 1
            FOR UPDATE
        ];
        if (!rows.isEmpty()) {
            cfg = rows[0];
            if (cfg.LastAssignedIndex__c != null) lastIdx = Integer.valueOf(cfg.LastAssignedIndex__c);
        }

        Integer teamSize = teamOrder.size();
        if (lastIdx < -1 || lastIdx >= teamSize) lastIdx = -1;

        Integer cursor = lastIdx; 

        List<Opportunity> updates = new List<Opportunity>();
        Date todayDate = Date.today();

        for (Opportunity opp : scope) {
            // Determine record type
            String rt = (opp.RecordType == null) ? null : opp.RecordType.DeveloperName;
            Boolean isLead = (rt == 'Lead');
            Boolean isOpp  = (rt == 'Opportunity');

            // Days since last activity (null => very old)
            Integer daysSince = (opp.Days_Since_Last_Activity__c == null)
                ? 99999
                : Integer.valueOf(opp.Days_Since_Last_Activity__c);

            // --- RULE: Tradeshow Leads (LSC_Campaign__c set on Lead) ---
            if (isLead) {
                String lsc = (String)opp.get('LSC_Campaign__c');
                if (!String.isBlank(lsc)) {
                    String lc = lsc.toLowerCase();
                    Boolean isTradeshow = lc.contains('tradeshow') || lc.contains('trade show');
                    if (isTradeshow) {
                        cursor = assignNext(opp, updates, teamOrder, teamSize, cursor);
                        continue;
                    }
                }
            }

            // --- RULE: Neglected Leads -> 24 working hours (Mon–Fri) ---
            if (isLead && opp.StageName == 'Neglected') {
                Date startDate = (opp.Neglected_Date__c != null) ? opp.Neglected_Date__c.date()
                    : (opp.LastModifiedDate != null ? opp.LastModifiedDate.date() : todayDate);

                Integer workDays = businessDaysBetween(startDate, todayDate);
                if (workDays >= 1) {
                    cursor = assignNext(opp, updates, teamOrder, teamSize, cursor);
                    if (opp.Neglected_Date__c == null) {
                        opp.Neglected_Date__c = todayDate;
                    }
                    continue;
                } else if (opp.Neglected_Date__c == null) {
                    opp.Neglected_Date__c = todayDate;
                    updates.add(opp);
                }
            }

            // --- RULE: In-Progress Leads -> 90+ days since last activity ---
            if (isLead && opp.StageName == 'In Progress' && daysSince >= 90) {
                cursor =  assignNext(opp, updates, teamOrder, teamSize, cursor);
                continue;
            }

            // --- RULE: Expired Opps -> CloseDate in past & 180+ days no activity ---
            if (isOpp && opp.CloseDate < todayDate && daysSince >= 180) {
                cursor =  assignNext(opp, updates, teamOrder, teamSize, cursor);
                continue;
            }
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }

        // Persist the last assigned index ONCE per chunk (if the setting exists)
        if (cfg != null) {
            cfg.LastAssignedIndex__c = cursor;
            update cfg;
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    // -------- Helpers --------
    private static Integer assignNext(
        Opportunity opp,
        List<Opportunity> updates,
        List<Id> teamOrder,
        Integer teamSize,
        Integer cursor
    ){
        if (teamSize <= 0) return cursor; // safety

        Integer nextCursor = cursor + 1;
        if (nextCursor >= teamSize) nextCursor = 0; // wrap around

        Id nextOwner = teamOrder[nextCursor];
        if (opp.OwnerId != nextOwner) {
            opp.OwnerId = nextOwner;
            updates.add(opp);
        }
        return nextCursor;
    }


    // Count Mon–Fri business days in [startDate, endDate)
    public static Integer businessDaysBetween(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate <= startDate) return 0;
        Integer count = 0;
        for (Date d = startDate; d < endDate; d = d.addDays(1)) {
            Integer dow = Integer.valueOf(
                DateTime.newInstance(d, Time.newInstance(0,0,0,0)).format('u')
            ); // 1=Mon … 7=Sun
            if (dow >= 1 && dow <= 5) {
                count++;
            }
        }
        return count;
    }

}