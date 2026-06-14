public with sharing class FileSizeValidator {
    @InvocableMethod(label='Validate File Sizes (Collection)' description='Checks if any ContentVersion files in a collection exceed the specified size limit (in bytes).')
    public static List<ValidationResult> validateFileSizesFromCollection(List<CollectionRequest> requests) {
        List<ValidationResult> results = new List<ValidationResult>();
        if (requests == null || requests.isEmpty()) {
            results.add(new ValidationResult('No ContentVersion IDs provided.', true));
            return results;
        }
        Set<Id> versionIds = new Set<Id>();
        Long maxSize = 10485760; // 10MB default
        for (CollectionRequest req : requests) {
            if (req.contentVersionIds != null) {
                for (String idStr : req.contentVersionIds) {
                    if (String.isNotBlank(idStr)) {
                        versionIds.add((Id)idStr.trim());
                    }
                }
            }
            if (req.maxFileSizeBytes != null) {
                maxSize = req.maxFileSizeBytes;
            }
        }
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
            SELECT Id, Title, ContentSize FROM ContentVersion WHERE Id IN :versionIds
        ]);
        Boolean hasError = false;
        String errorMsg = '';
        for (ContentVersion cv : versionMap.values()) {
            if (cv.ContentSize > maxSize) {
                hasError = true;
                errorMsg += 'File "' + cv.Title + '" exceeds the size limit (' + cv.ContentSize + ' bytes).\n';
            }
        }
        if (hasError) {
            results.add(new ValidationResult(errorMsg, true));
        } else {
            results.add(new ValidationResult('All files are within the size limit.', false));
        }
        return results;
    }

    public class CollectionRequest {
        @InvocableVariable(label='Content Version IDs (Collection)' required=true)
        public List<String> contentVersionIds;
        @InvocableVariable(label='Max File Size (bytes)' required=false)
        public Long maxFileSizeBytes;
    }

    public class ValidationResult {
        @InvocableVariable(label='Error Message')
        public String errorMessage;
        @InvocableVariable(label='Has Error')
        public Boolean hasError;
        public ValidationResult(String msg, Boolean err) {
            errorMessage = msg;
            hasError = err;
        }
    }
}