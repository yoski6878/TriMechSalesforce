public without sharing class RunContactNukeBatchAction {
    public class Request {
        @InvocableVariable(required=true label='Contact ID') public Id recordId;
        @InvocableVariable(required=true label='Operation' description='PREVIEW or DEACTIVATE') public String operation;
    }
    public class Response {
        @InvocableVariable(label='Impact Summary') public String summary;
        @InvocableVariable(label='Related Record Count') public Integer relatedRecordCount;
        @InvocableVariable(label='Completed') public Boolean completed;
    }
    @InvocableMethod(label='Preview or Run NUKE Contact Deactivation')
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            NukeDeactivationService.Preview preview = NukeDeactivationService.previewContact(request.recordId);
            Response response = new Response();
            response.summary = preview.summary('Contact');
            response.relatedRecordCount = preview.totalRelated();
            response.completed = false;
            if ('DEACTIVATE'.equalsIgnoreCase(request.operation)) {
                NukeDeactivationService.deactivateContact(request.recordId);
                response.completed = true;
                response.summary = 'The selected Contact and ' + response.relatedRecordCount + ' related records were deactivated. No records were deleted.';
            } else if (!'PREVIEW'.equalsIgnoreCase(request.operation)) {
                throw new IllegalArgumentException('Operation must be PREVIEW or DEACTIVATE.');
            }
            responses.add(response);
        }
        return responses;
    }
}
