// Run as a separate execution after cleanup-1. Needs field-level security on User.Hire_Date__c for your user.
update new User(Id = UserInfo.getUserId(), ManagerId = null);
User u = new User(Id = UserInfo.getUserId());
u.put('Hire_Date__c', null);
update u;
delete [SELECT Id FROM GroupMember WHERE Group.DeveloperName = 'Proposal_Approval_High_Offenders'];
