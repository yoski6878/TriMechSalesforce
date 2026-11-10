public without sharing class RunContactNukeBatchAction {
    public class Request {
        @InvocableVariable(required=true label='Contact ID') public Id recordId;
        @InvocableVariable(required=true label='Operation' description='PREVIEW or RUN') public String operation;
    }
    public class Response {
        @InvocableVariable(label='Impact Summary') public String summary;
        @InvocableVariable(label='Related Record Count') public Integer relatedRecordCount;
        @InvocableVariable(label='Action' description='Inactivated or Deleted') public String action;
        @InvocableVariable(label='Completed') public Boolean completed;
    }
    @InvocableMethod(label='Preview or Run NUKE Contact Cleanup')
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            NukeDeactivationService.ContactPreview preview = NukeDeactivationService.previewContact(request.recordId);
            Response response = new Response();
            response.summary = preview.summary();
            response.relatedRecordCount = preview.totalRelated();
            response.action = preview.action;
            response.completed = false;
            if ('RUN'.equalsIgnoreCase(request.operation)) {
                NukeDeactivationService.ContactResult contactResult = NukeDeactivationService.runContact(request.recordId).contacts[0];
                if (!contactResult.isSuccess()) {
                    throw new NukeException('NUKE could not update this Contact: ' + contactResult.error);
                }
                response.action = contactResult.action;
                response.completed = true;
                response.summary = contactResult.action == NukeDeactivationService.ACTION_DELETED
                    ? 'The Contact was deleted. Reason: ' + contactResult.reason + '.\n' +
                        'It was removed from ' + contactResult.assetsCleared + ' Asset(s) and ' + contactResult.opportunitiesUpdated +
                        ' Opportunity Order Management list(s). Related records were kept. It can be restored from the Recycle Bin for 15 days.'
                    : 'The Contact was marked Inactive. It was NOT deleted. Reason: ' + contactResult.reason + '.\n' +
                        'Related records stay active and stay linked to the Contact.';
            } else if (!'PREVIEW'.equalsIgnoreCase(request.operation)) {
                throw new IllegalArgumentException('Operation must be PREVIEW or RUN.');
            }
            responses.add(response);
        }
        return responses;
    }

    public class NukeException extends Exception {}
}
