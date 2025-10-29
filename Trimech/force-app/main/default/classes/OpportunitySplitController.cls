public without sharing class OpportunitySplitController {
    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserTeamMember(Id opportunityId) {
        try {
            Id currentUserId = UserInfo.getUserId();
            // 1. Team members
            Set<Id> teamUserIds = new Set<Id>();
            for (OpportunityTeamMember tm : [
                SELECT UserId FROM OpportunityTeamMember WHERE OpportunityId = :opportunityId
            ]) {
                teamUserIds.add(tm.UserId);
            }
            if (teamUserIds.contains(currentUserId)) {
                return true;
            }
            // 2. Managers of team members
            Set<Id> managerIds = new Set<Id>();
            for (User u : [SELECT ManagerId FROM User WHERE Id IN :teamUserIds AND ManagerId != null]) {
                managerIds.add(u.ManagerId);
            }
            if (managerIds.contains(currentUserId)) {
                return true;
            }
            // 3 & 4. Public Groups: Management Team and Sales_Ops (support nested group membership)
            List<Group> targetGroups = [SELECT Id FROM Group WHERE (Name = 'Management Team' OR Name = 'Sales_Ops') AND Type = 'Regular'];
            Set<Id> targetGroupIds = new Set<Id>();
            for (Group g : targetGroups) {
                targetGroupIds.add(g.Id);
            }
            if (!targetGroupIds.isEmpty()) {
                // Find all groups the user belongs to (directly or via nested groups)
                Set<Id> userGroups = new Set<Id>();
                // Start with direct groups
                for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :currentUserId]) {
                    userGroups.add(gm.GroupId);
                }
                // Recursively add parent groups for nested group membership
                Boolean foundNew = true;
                while (foundNew) {
                    foundNew = false;
                    List<GroupMember> parentLinks = [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :userGroups];
                    for (GroupMember gm : parentLinks) {
                        if (!userGroups.contains(gm.GroupId)) {
                            userGroups.add(gm.GroupId);
                            foundNew = true;
                        }
                    }
                }
                // If any of the user's groups match the target groups, grant access
                for (Id gId : targetGroupIds) {
                    if (userGroups.contains(gId)) {
                        return true;
                    }
                }
            }
            // 5. System Administrator or Sales Manager profile
            User currentUser = [SELECT Profile.Name FROM User WHERE Id = :currentUserId];
            if (currentUser.Profile.Name == 'System Administrator' || currentUser.Profile.Name == 'Sales Manager') {
                return true;
            }
            return false;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking team membership: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static List<User> getOpportunityTeamMembers(Id opportunityId) {
        try {
            List<OpportunityTeamMember> teamMembers = [
                SELECT UserId, User.Name, User.Email
                FROM OpportunityTeamMember
                WHERE OpportunityId = :opportunityId
            ];
            Set<Id> userIds = new Set<Id>();
            for (OpportunityTeamMember tm : teamMembers) {
                userIds.add(tm.UserId);
            }
            if (userIds.isEmpty()) {
                return new List<User>();
            }
            return [SELECT Id, Name, Email FROM User WHERE Id IN :userIds AND IsActive = true ORDER BY Name];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving team member users: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunitySplit> getOpportunitySplits(String opportunityId) {
        // Handle null or empty opportunityId
        if (opportunityId == null || opportunityId == '') {
            return new List<OpportunitySplit>();
        }
        String COMMISSIONABLE_GP_SPLIT_TYPE_ID = '1494V00000009uwQAA';
        try {
            List<OpportunitySplit> splits = [
                SELECT Id, SplitOwnerId, SplitPercentage, SplitAmount, Split_Owner_NetSuite_Id__c, SplitTypeId, OpportunityId, SplitNote
                FROM OpportunitySplit 
                WHERE OpportunityId = :opportunityId
                AND SplitTypeId = :COMMISSIONABLE_GP_SPLIT_TYPE_ID
                AND IsDeleted = false
                ORDER BY CreatedDate DESC
            ];
            return splits;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving opportunity splits: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createOpportunitySplits(List<Map<String, Object>> splitObjs) {
        String COMMISSIONABLE_GP_SPLIT_TYPE_ID = '1494V00000009uwQAA';
        try {
            if (splitObjs != null && !splitObjs.isEmpty()) {
                System.debug('createOpportunitySplits input: ' + JSON.serialize(splitObjs));
                List<String> pctDebug = new List<String>();
                for (Map<String, Object> splitMap : splitObjs) {
                    pctDebug.add(String.valueOf(splitMap.get('SplitOwnerId')) + ':' + String.valueOf(splitMap.get('SplitPercentage')));
                }
                System.debug('SplitOwnerId:SplitPercentage pairs: ' + String.join(pctDebug, ', '));
                Id opportunityId;
                for (Map<String, Object> splitMap : splitObjs) {
                    if (splitMap.containsKey('OpportunityId')) {
                        Object oppIdVal = splitMap.get('OpportunityId');
                        if (oppIdVal != null) {
                            opportunityId = (Id)String.valueOf(oppIdVal);
                            break;
                        }
                    }
                }
                if (opportunityId == null) {
                    return 'Error: No OpportunityId provided.';
                }
                List<OpportunitySplit> existingSplits = [
                    SELECT Id, SplitOwnerId, SplitPercentage, SplitTypeId
                    FROM OpportunitySplit
                    WHERE OpportunityId = :opportunityId
                    AND SplitTypeId = :COMMISSIONABLE_GP_SPLIT_TYPE_ID
                    AND IsDeleted = false
                ];
                Map<Id, OpportunitySplit> ownerToSplit = new Map<Id, OpportunitySplit>();
                for (OpportunitySplit s : existingSplits) {
                    ownerToSplit.put(s.SplitOwnerId, s);
                }
                Set<Id> incomingOwnerIds = new Set<Id>();
                for (Map<String, Object> splitMap : splitObjs) {
                    Id ownerId;
                    Object ownerVal = splitMap.get('SplitOwnerId');
                    if (ownerVal != null) ownerId = (Id)String.valueOf(ownerVal);
                    Decimal pct;
                    Object pctVal = splitMap.get('SplitPercentage');
                    if (pctVal != null) pct = Decimal.valueOf(String.valueOf(pctVal));
                    if (ownerId == null || pct == null) continue;
                    incomingOwnerIds.add(ownerId);
                    if (ownerToSplit.containsKey(ownerId)) {
                        ownerToSplit.get(ownerId).SplitPercentage = pct;
                        if (splitMap.containsKey('SplitNote')) ownerToSplit.get(ownerId).SplitNote = (String)splitMap.get('SplitNote');
                    } else {
                        OpportunitySplit newSplit = new OpportunitySplit();
                        newSplit.SplitOwnerId = ownerId;
                        newSplit.SplitPercentage = pct;
                        newSplit.OpportunityId = opportunityId;
                        newSplit.SplitTypeId = COMMISSIONABLE_GP_SPLIT_TYPE_ID;
                        if (splitMap.containsKey('SplitNote')) newSplit.SplitNote = (String)splitMap.get('SplitNote');
                        ownerToSplit.put(ownerId, newSplit);
                    }
                }
                // Find splits to delete (in existing but not in incoming)
                List<OpportunitySplit> splitsToDelete = new List<OpportunitySplit>();
                for (OpportunitySplit s : existingSplits) {
                    if (!incomingOwnerIds.contains(s.SplitOwnerId)) {
                        splitsToDelete.add(s);
                    }
                }
                // Step 1: Set splits to be deleted to 0% and upsert them
                for (OpportunitySplit s : splitsToDelete) {
                    s.SplitPercentage = 0;
                }
                // Prepare all splits to upsert (including 0% ones)
                List<OpportunitySplit> splitsToUpsert = new List<OpportunitySplit>();
                Decimal total = 0;
                for (OpportunitySplit s : ownerToSplit.values()) {
                    splitsToUpsert.add(s);
                    if (s.SplitPercentage == null) s.SplitPercentage = 0;
                    total += s.SplitPercentage;
                }
                for (OpportunitySplit s : splitsToDelete) {
                    if (!splitsToUpsert.contains(s)) {
                        splitsToUpsert.add(s);
                        total += s.SplitPercentage;
                    }
                }
                // If only one split remains, force it to 100%
                if (splitsToUpsert.size() - splitsToDelete.size() == 1) {
                    for (OpportunitySplit s : splitsToUpsert) {
                        if (!splitsToDelete.contains(s)) {
                            s.SplitPercentage = 100;
                            total = 100;
                        }
                    }
                }
                if (total != 100) {
                    return 'Error: Split percentages must sum to 100%. Current total: ' + total;
                }
                // Upsert all splits (including 0% ones)
                if (!splitsToUpsert.isEmpty()) {
                    upsert splitsToUpsert;
                }
                // Step 2: Delete the 0% splits
                if (!splitsToDelete.isEmpty()) {
                    delete splitsToDelete;
                }
                return 'Success: ' + splitsToUpsert.size() + ' splits upserted, ' + splitsToDelete.size() + ' deleted.';
            }
            return 'No split provided.';
        } catch (Exception e) {
            return 'Error creating split: ' + e.getMessage() + ' - ' + e.getCause();
        }
    }
    
    @AuraEnabled
    public static String deleteOpportunitySplits(List<Id> splitIds) {
        String COMMISSIONABLE_GP_SPLIT_TYPE_ID = '1494V00000009uwQAA';
        try {
            if (splitIds != null && !splitIds.isEmpty()) {
                List<OpportunitySplit> splitsToDelete = [
                    SELECT Id 
                    FROM OpportunitySplit 
                    WHERE Id IN :splitIds
                    AND SplitTypeId = :COMMISSIONABLE_GP_SPLIT_TYPE_ID
                ];
                if (!splitsToDelete.isEmpty()) {
                    delete splitsToDelete;
                    return 'Success: ' + splitsToDelete.size() + ' splits deleted.';
                }
                return 'No splits found to delete.';
            }
            return 'No split IDs provided.';
        } catch (Exception e) {
            return 'Error deleting splits: ' + e.getMessage();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<User> getUserOptions() {
        try {
            List<User> users = [
                SELECT Id, Name, Email
                FROM User 
                WHERE IsActive = true
                ORDER BY Name
            ];
            return users;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving user options: ' + e.getMessage());
        }
    }
}