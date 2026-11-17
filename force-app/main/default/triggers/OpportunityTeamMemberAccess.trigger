trigger OpportunityTeamMemberAccess on OpportunityTeamMember (before insert, before update) {
    Set<String> editableRoles = new Set<String>{
        'Technical Resource',
        'Owner',
        'Opportunity Owner',
        'Sales Rep'
    };

    for (OpportunityTeamMember member : Trigger.new) {
        if (editableRoles.contains(member.TeamMemberRole)) {
            member.OpportunityAccessLevel = 'Edit';
        }
    }
}
