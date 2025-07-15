public class FeedCommentTriggerHandler {
    public static void handleAfterInsert(List<FeedComment> newComments) {
        Set<Id> caseIdsToCheck = new Set<Id>();
        Set<Id> userIds = new Set<Id>();

        for (FeedComment comment : newComments) {
            if (comment.ParentId != null && comment.ParentId.getSObjectType() == Case.SObjectType) {
                caseIdsToCheck.add(comment.ParentId);
                userIds.add(comment.CreatedById);
            }
        }

        if (caseIdsToCheck.isEmpty() || userIds.isEmpty()) {
            return;
        }

        // Get users with their profiles
        Map<Id, User> userMap = new Map<Id, User>(
            [SELECT Id, Profile.Name FROM User WHERE Id IN :userIds]
        );

        // Filter to keep only feedcomments by "Trimech Support" profile users
        List<FeedComment> relevantComments = new List<FeedComment>();
        for (FeedComment comment : newComments) {
            User commenter = userMap.get(comment.CreatedById);
            if (comment.ParentId != null &&
                comment.ParentId.getSObjectType() == Case.SObjectType &&
                commenter != null &&
                commenter.Profile.Name == 'TriMech Customer Portal Profile') {
                    relevantComments.add(comment);
            }
        }

        if (relevantComments.isEmpty()) {
            return;
        }

        // Get related Cases and Owner info
        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, Status, CaseNumber, Subject, OwnerId, Owner.Name, Owner.Email FROM Case
             WHERE Id IN :caseIdsToCheck]
        );

        List<Case> casesToUpdate = new List<Case>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (FeedComment comment : relevantComments) {
            Case relatedCase = caseMap.get(comment.ParentId);
            if (relatedCase != null && relatedCase.Status == 'Waiting for Client') {
                relatedCase.Status = 'In Progress';
                casesToUpdate.add(relatedCase);

                // Prepare the email
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                //mail.setTargetObjectId(relatedCase.OwnerId);
                mail.setToAddresses(new String[] { relatedCase.Owner.Email });
                mail.setWhatId(relatedCase.Id); // Link email to Case as related record
                mail.setSaveAsActivity(true);
                mail.setSubject('New Feed Comment received on Case #' + relatedCase.CaseNumber);

                String body = 'Hi ' + relatedCase.Owner.Name + ',\n\n' +
                              'A new Case Comment has been added to Case ' + relatedCase.CaseNumber + ':\n\n' +
                              comment.CommentBody + '\n\n' +
                              'Thank you,\n' +
                              'The TriMech Team';

                mail.setPlainTextBody(body);
                emailsToSend.add(mail);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }
}