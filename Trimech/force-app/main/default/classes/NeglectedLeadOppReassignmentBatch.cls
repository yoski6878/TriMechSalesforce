global class NeglectedLeadOppReassignmentBatch
implements Database.Batchable<SObject>, Database.Stateful {

    // Cached across the batch (Stateful)
    private List<Id> hardwareTeamOrder = new List<Id>();
    private Set<Id> hardwareTeamIds = new Set<Id>();
    private List<Id> softwareTeamOrder = new List<Id>();
    private Set<Id> softwareTeamIds = new Set<Id>();

    public NeglectedLeadOppReassignmentBatch() {}

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Hardware/AMS team
        List<String> hwAliasList = new List<String>();
        String neglectedLeadAlias = System.label.NeglectedLeadExceptionAlias;
        if (neglectedLeadAlias != null && neglectedLeadAlias != '' && !String.isBlank(neglectedLeadAlias)) {
            if (neglectedLeadAlias.contains(',')) {
                hwAliasList = neglectedLeadAlias.split(',');
            } else {
                hwAliasList.add(neglectedLeadAlias);
            }
        }
        List<String> hwIncludeList = new List<String>();
        String hwInclude = System.label.NeglectedLeadHardwareIncludeAlias;
        if (!String.isBlank(hwInclude)) {
            hwIncludeList = hwInclude.split(',');
        }
        List<User> hardwareTeam = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND (
                ((Manager.Name = 'Julio Nunez' AND Profile.Name = 'Hardware Inside') OR Name = 'Julio Nunez')
                OR alias IN :hwIncludeList
              )
              AND alias NOT IN :hwAliasList
            ORDER BY Name
        ];
        for (User u : hardwareTeam) {
            hardwareTeamOrder.add(u.Id);
            hardwareTeamIds.add(u.Id);
        }

        // Software team
        List<String> swAliasList = new List<String>();
        String softwareLeadAlias = System.label.NeglectedLeadSoftwareExceptionAlias;
        if (softwareLeadAlias != null && softwareLeadAlias != '' && !String.isBlank(softwareLeadAlias)) {
            if (softwareLeadAlias.contains(',')) {
                swAliasList = softwareLeadAlias.split(',');
            } else {
                swAliasList.add(softwareLeadAlias);
            }
        }
        List<String> swIncludeList = new List<String>();
        String swInclude = System.label.NeglectedLeadSoftwareIncludeAlias;
        if (!String.isBlank(swInclude)) {
            swIncludeList = swInclude.split(',');
        }
        List<User> softwareTeam = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND (
                Title = 'Sales Development Representative - Contractor'
                OR alias IN :swIncludeList
              )
              AND alias NOT IN :swAliasList
            ORDER BY Name
        ];
        for (User u : softwareTeam) {
            softwareTeamOrder.add(u.Id);
            softwareTeamIds.add(u.Id);
        }

        if (Test.isRunningTest()) {
            return Database.getQueryLocator([
                SELECT Id, Name, OwnerId, RecordType.DeveloperName, StageName,
                       ProductGroup_Name__c, CloseDate, LastModifiedDate,
                       Neglected_Date__c, LSC_Campaign__c, Days_Since_Last_Activity__c,
                       IsClosed
                FROM Opportunity
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, RecordType.DeveloperName, StageName,
                   ProductGroup_Name__c, CloseDate, LastModifiedDate,
                   Neglected_Date__c, LSC_Campaign__c, Days_Since_Last_Activity__c,
                   IsClosed
            FROM Opportunity
            WHERE ProductGroup_Name__c IN ('Hardware','AMS','Software','Staffing','Product Development','SSG-CRE','CPQ','Aras','SSG-BT','SolidCAM')
                AND IsClosed = false
                AND CreatedDate >= 2026-01-01T00:00:00Z
                AND (
                    (ProductGroup_Name__c IN ('Hardware','AMS') AND OwnerId NOT IN :hardwareTeamIds)
                    OR (ProductGroup_Name__c IN ('Software','Staffing','Product Development','SSG-CRE','CPQ','Aras','SSG-BT','SolidCAM') AND OwnerId NOT IN :softwareTeamIds)
                )
                AND (
                    (RecordType.DeveloperName = 'Lead' AND (LSC_Campaign__c LIKE '%tradeshow%' OR LSC_Campaign__c LIKE '%trade show%'))
                    OR (RecordType.DeveloperName = 'Lead' AND StageName = 'Neglected')
                    OR (RecordType.DeveloperName = 'Lead' AND StageName = 'In Progress' AND Days_Since_Last_Activity__c >= 90)
                    OR (RecordType.DeveloperName = 'Opportunity' AND CloseDate < TODAY AND Days_Since_Last_Activity__c >= 180)
                )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        // Handle both teams
        if (hardwareTeamOrder.isEmpty() && softwareTeamOrder.isEmpty()) {
            System.debug(LoggingLevel.WARN, '[NeglectedLeadOppReassignmentBatch] No team members found in hardware or software teams. Exiting batch.');
            return;
        }

        // RoundRobin config for each team
        Map<String, RoundRobin__c> cfgMap = new Map<String, RoundRobin__c>();
        Map<String, Integer> lastIdxMap = new Map<String, Integer>{'Hardware' => -1, 'AMS' => -1, 'Software' => -1};
        List<RoundRobin__c> rows = [
            SELECT Id, Name, LastAssignedIndex__c
            FROM RoundRobin__c
            WHERE Name IN ('HardwareTeam', 'SoftwareTeam')
            FOR UPDATE
        ];
        for (RoundRobin__c row : rows) {
            cfgMap.put(row.Name, row);
            if (row.Name == 'HardwareTeam' && row.LastAssignedIndex__c != null) lastIdxMap.put('Hardware', Integer.valueOf(row.LastAssignedIndex__c));
            if (row.Name == 'HardwareTeam' && row.LastAssignedIndex__c != null) lastIdxMap.put('AMS', Integer.valueOf(row.LastAssignedIndex__c));
            if (row.Name == 'SoftwareTeam' && row.LastAssignedIndex__c != null) lastIdxMap.put('Software', Integer.valueOf(row.LastAssignedIndex__c));
        }

        Map<String, List<Id>> teamOrderMap = new Map<String, List<Id>>{
            'Hardware' => hardwareTeamOrder,
            'AMS' => hardwareTeamOrder,
            'Software' => softwareTeamOrder
        };
        Map<String, Integer> teamSizeMap = new Map<String, Integer>{
            'Hardware' => hardwareTeamOrder.size(),
            'AMS' => hardwareTeamOrder.size(),
            'Software' => softwareTeamOrder.size()
        };

        Map<String, Integer> cursorMap = new Map<String, Integer>{
            'Hardware' => lastIdxMap.get('Hardware'),
            'AMS' => lastIdxMap.get('AMS'),
            'Software' => lastIdxMap.get('Software')
        };

        List<Opportunity> updates = new List<Opportunity>();
        Date todayDate = Date.today();

        System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Processing ' + scope.size() + ' Opportunities in batch scope.');
        for (Opportunity opp : scope) {
            String pg = String.valueOf(opp.ProductGroup_Name__c);
            String teamKey = (
                pg == 'Software' || pg == 'Staffing' || pg == 'Product Development' || pg == 'SSG-CRE' || pg == 'CPQ' || pg == 'Aras' || pg == 'SSG-BT' || pg == 'SolidCAM'
            ) ? 'Software' : (pg == 'AMS' ? 'AMS' : 'Hardware');
            List<Id> teamOrder = teamOrderMap.get(teamKey);
            Integer teamSize = teamSizeMap.get(teamKey);
            Integer cursor = cursorMap.get(teamKey);

            System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ' (' + opp.Name + '), ProductGroup=' + pg + ', teamKey=' + teamKey + ', teamSize=' + teamSize + ', currentOwner=' + opp.OwnerId);

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
                        System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Tradeshow lead detected. Assigning to next user in ' + teamKey + ' team.');
                        cursor = assignNext(opp, updates, teamOrder, teamSize, cursor);
                        System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Assigned to user ' + opp.OwnerId);
                        cursorMap.put(teamKey, cursor);
                        continue;
                    }
                }
            }

            // --- RULE: Neglected Leads -> 24 working hours (Mon–Fri) ---
            if (isLead && opp.StageName == 'Neglected') {
                Date startDate = (opp.Neglected_Date__c != null) ? opp.Neglected_Date__c.date()
                    : (opp.LastModifiedDate != null ? opp.LastModifiedDate.date() : todayDate);

                Integer workDays = businessDaysBetween(startDate, todayDate);
                System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Neglected lead, workDays=' + workDays + ', startDate=' + startDate + ', today=' + todayDate);
                if (workDays >= 2) {
                    System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Neglected for >=2 business days. Assigning to next user in ' + teamKey + ' team.');
                    Id prevOwner = opp.OwnerId;
                    cursor = assignNext(opp, updates, teamOrder, teamSize, cursor);
                    System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Assigned to user ' + opp.OwnerId);
                    cursorMap.put(teamKey, cursor);
                    // Restart the neglect clock so the new owner gets a fresh 2-business-day
                    // window; otherwise the stale anchor keeps workDays >= 2 and the lead is
                    // reassigned on every subsequent run.
                    opp.Neglected_Date__c = todayDate;
                    if (opp.OwnerId == prevOwner) {
                        // assignNext only enqueues on owner change; the date still changed.
                        updates.add(opp);
                    }
                    continue;
                } else if (opp.Neglected_Date__c == null) {
                    System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Neglected_Date__c was null, setting to today.');
                    opp.Neglected_Date__c = todayDate;
                    updates.add(opp);
                } else {
                    System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Not neglected long enough for reassignment.');
                }
            }

            // --- RULE: In-Progress Leads -> 90+ days since last activity ---
            if (isLead && opp.StageName == 'In Progress' && daysSince >= 90) {
                System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': In Progress lead, daysSince=' + daysSince + '. Assigning to next user in ' + teamKey + ' team.');
                cursor =  assignNext(opp, updates, teamOrder, teamSize, cursor);
                System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Assigned to user ' + opp.OwnerId);
                cursorMap.put(teamKey, cursor);
                continue;
            }

            // --- RULE: Expired Opps -> CloseDate in past & 180+ days no activity ---
            if (isOpp && opp.CloseDate < todayDate && daysSince >= 180) {
                System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Expired Opp, daysSince=' + daysSince + ', CloseDate=' + opp.CloseDate + '. Assigning to next user in ' + teamKey + ' team.');
                cursor =  assignNext(opp, updates, teamOrder, teamSize, cursor);
                System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': Assigned to user ' + opp.OwnerId);
                cursorMap.put(teamKey, cursor);
                continue;
            }

            System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Opportunity ' + opp.Id + ': No reassignment rule matched.');
        }

        if (!updates.isEmpty()) {
            System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] Updating ' + updates.size() + ' Opportunities.');
            Database.update(updates, false);
        } else {
            System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] No Opportunities to update.');
        }

        // Persist the last assigned index for each team (if the setting exists)
        if (cfgMap.containsKey('HardwareTeam')) {
            System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Persisting HardwareTeam LastAssignedIndex__c = ' + cursorMap.get('Hardware'));
            cfgMap.get('HardwareTeam').LastAssignedIndex__c = cursorMap.get('Hardware');
            update cfgMap.get('HardwareTeam');
        }
        if (cfgMap.containsKey('SoftwareTeam')) {
            System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] Persisting SoftwareTeam LastAssignedIndex__c = ' + cursorMap.get('Software'));
            cfgMap.get('SoftwareTeam').LastAssignedIndex__c = cursorMap.get('Software');
            update cfgMap.get('SoftwareTeam');
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
        if (teamSize <= 0) {
            System.debug(LoggingLevel.WARN, '[NeglectedLeadOppReassignmentBatch] assignNext: No team members available for assignment.');
            return cursor; // safety
        }

        Integer nextCursor = cursor + 1;
        if (nextCursor >= teamSize) nextCursor = 0; // wrap around

        Id nextOwner = teamOrder[nextCursor];
        if (opp.OwnerId != nextOwner) {
            System.debug(LoggingLevel.INFO, '[NeglectedLeadOppReassignmentBatch] assignNext: Reassigning Opportunity ' + opp.Id + ' from ' + opp.OwnerId + ' to ' + nextOwner);
            opp.OwnerId = nextOwner;
            updates.add(opp);
        } else {
            System.debug(LoggingLevel.DEBUG, '[NeglectedLeadOppReassignmentBatch] assignNext: Opportunity ' + opp.Id + ' already assigned to ' + nextOwner + ', skipping update.');
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