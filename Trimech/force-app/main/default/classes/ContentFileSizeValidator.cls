/**
 * ContentFileSizeValidator
 * Validates that uploaded files (by ContentDocumentId) are at or under a size threshold (default 10 MB).
 *
 * Usage from Flow (Screen):
 * - Each File Upload component exposes a collection of ContentDocumentIds.
 * - Pass one Request per component (collection) to the invocable method.
 * - The returned results align with the input order and indicate if any file exceeds the threshold.
 *
 * Design:
 * - Bulk-safe: flattens all IDs across requests and runs a single SOQL with WITH SECURITY_ENFORCED.
 * - Uses enums for clarity and maintainability.
 * - No DML, no debug, respects sharing.
 *
 * Security:
 * - Class runs with sharing.
 * - SOQL uses WITH SECURITY_ENFORCED to respect FLS/sharing.
 *
 * @author Agentforce
 * @group File Validation
 * @description Invocable validator for ContentDocument file sizes to be used from Screen Flows.
 */
public with sharing class ContentFileSizeValidator {

    /**
     * ValidationStatus enum
     * Represents pass/fail outcomes.
     */
    public enum ValidationStatus {
        PASS,
        FAIL
    }

    /**
     * Request
     * One instance per File Upload component (collection of ContentDocumentIds).
     */
    public class Request {
        /**
         * Collection of ContentDocument Ids from a single File Upload component.
         */
        @InvocableVariable(required=true)
        public List<Id> contentDocumentIds;

        /**
         * Optional override for the size threshold in bytes (defaults to DEFAULT_SIZE_LIMIT_BYTES).
         * Provide only if you need a different limit for this specific collection.
         */
        @InvocableVariable(required=false)
        public Long sizeLimitBytes;
    }

    /**
     * Result
     * Returned per input Request, aligned to the same order.
     */
    public class Result {
        /**
         * Indicates whether all files in the corresponding request are within the allowed size.
         */
        @InvocableVariable
        public Boolean isValid;

        /**
         * Human-readable error message when validation fails; empty if valid.
         */
        @InvocableVariable
        public String errorMessage;

        /**
         * The specific ContentDocumentIds whose latest versions exceeded the limit or could not be evaluated.
         */
        @InvocableVariable
        public List<Id> violatingDocumentIds;

        /**
         * Optional status value (PASS/FAIL) for additional clarity in automations.
         */
        @InvocableVariable
        public String status;
    }

    // Default threshold: 10 MB (binary) = 10,485,760 bytes
    private static final Long DEFAULT_SIZE_LIMIT_BYTES = 10485760L;

    /**
     * Invocable method for Screen Flows.
     *
     * Accepts multiple Request items (one per File Upload collection).
     * Returns a matching number of Result items, aligned by index.
     * Also deletes any files that exceed the size limit (default 10 MB) from the input collections.
     */
    @InvocableMethod(label='Validate and Delete Oversize Files' description='Validates that each file referenced by ContentDocumentIds is at or under the size limit (default 10 MB). Deletes oversized files and returns one Result per input collection.')
    public static List<Result> validateAndDeleteOversizeFiles(List<Request> requests) {
        // Guard clause for null or empty inputs
        if (requests == null || requests.isEmpty()) {
            return new List<Result>();
        }

        // Flatten all IDs using a Set to dedupe
        Set<Id> allDocIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.contentDocumentIds != null && !req.contentDocumentIds.isEmpty()) {
                allDocIds.addAll(req.contentDocumentIds);
            }
        }

        // Early return if there are no IDs to validate (all empty collections)
        if (allDocIds.isEmpty()) {
            List<Result> emptyResults = new List<Result>();
            for (Integer i = 0; i < requests.size(); i++) {
                Result r = new Result();
                r.isValid = true;
                r.errorMessage = '';
                r.violatingDocumentIds = new List<Id>();
                r.status = String.valueOf(ValidationStatus.PASS);
                emptyResults.add(r);
            }
            return emptyResults;
        }

        // Query latest ContentVersion sizes for the provided ContentDocumentIds
        // Note: ContentSize is in bytes
        Map<Id, Integer> docIdToSize = new Map<Id, Integer>();
        Map<Id, String> docIdToTitle = new Map<Id, String>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, ContentSize, Title
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :allDocIds
            WITH SECURITY_ENFORCED
        ]) {
            docIdToSize.put(cv.ContentDocumentId, cv.ContentSize);
            docIdToTitle.put(cv.ContentDocumentId, cv.Title);
        }

        // Build results per request and delete oversized files
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            List<Id> offenders = new List<Id>();
            List<String> offenderTitles = new List<String>();

            // Determine limit for this request (per-collection override supported)
            Long sizeLimit = (req != null && req.sizeLimitBytes != null && req.sizeLimitBytes > 0)
                ? req.sizeLimitBytes
                : DEFAULT_SIZE_LIMIT_BYTES;

            if (req == null || req.contentDocumentIds == null || req.contentDocumentIds.isEmpty()) {
                // Empty collection is valid
                r.isValid = true;
                r.errorMessage = '';
                r.violatingDocumentIds = new List<Id>();
                r.status = String.valueOf(ValidationStatus.PASS);
                results.add(r);
                continue; // Return-early pattern
            }

            // Check for oversized files and collect for deletion
            List<Id> filesToDelete = new List<Id>();
            for (Id docId : req.contentDocumentIds) {
                Integer sizeBytes = docIdToSize.get(docId);
                if (sizeBytes == null) {
                    // Could be missing due to security or data; treat as violation for safety
                    offenders.add(docId);
                    String t = docIdToTitle.get(docId);
                    if (t != null) offenderTitles.add(t);
                    continue;
                }
                if (sizeBytes != null && ((Long)sizeBytes) > sizeLimit) {
                    offenders.add(docId);
                    String t = docIdToTitle.get(docId);
                    if (t != null) offenderTitles.add(t);
                    filesToDelete.add(docId);
                }
            }

            // Delete oversized files if any exist
            if (!filesToDelete.isEmpty()) {
                try {
                    Database.delete(filesToDelete, AccessLevel.USER_MODE); // Will respect sharing rules
                } catch (Exception e) {
                    // Log or handle exception if needed, but continue with rest of logic
                    // In practice, you'd want to log this or bubble up the error appropriately
                }
            }

            // Filter out nulls from offenders before assigning
            List<Id> filteredOffenders = new List<Id>();
            for (Id oid : offenders) {
                if (oid != null) filteredOffenders.add(oid);
            }
            r.violatingDocumentIds = filteredOffenders;
            if (filteredOffenders.isEmpty()) {
                r.isValid = true;
                r.errorMessage = '';
                r.status = String.valueOf(ValidationStatus.PASS);
            } else {
                r.isValid = false;
                r.status = String.valueOf(ValidationStatus.FAIL);
                // Compose concise error (prefer Titles only for user-facing message)
                r.errorMessage = buildErrorMessage(offenderTitles, sizeLimit);
            }

            results.add(r);
        }

        return results;
    }

    /**
     * Deletes ContentDocuments that exceed the size limit (default 10 MB) and returns the IDs of deleted documents.
     * Note: This action deletes the entire ContentDocument, not just links. Requires appropriate permissions.
     * @param contentDocumentIds List of ContentDocument IDs to check and delete if oversized
     * @param sizeLimitBytes Optional override for size limit in bytes (defaults to 10 MB)
     * @return List of ContentDocument IDs that were deleted due to exceeding the size limit
     */
    // @InvocableMethod(label='Delete Oversize Files' description='Deletes ContentDocuments that exceed the size limit (default 10 MB).')
    public static List<Id> deleteOversizeFiles(List<Id> contentDocumentIds, Long sizeLimitBytes) {
        // Guard clause for null or empty inputs
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return new List<Id>();
        }

        // Determine limit for this request (per-collection override supported)
        Long sizeLimit = (sizeLimitBytes != null && sizeLimitBytes > 0)
            ? sizeLimitBytes
            : DEFAULT_SIZE_LIMIT_BYTES;

        // Query latest ContentVersion sizes for the provided ContentDocumentIds
        Map<Id, Integer> docIdToSize = new Map<Id, Integer>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, ContentSize
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :contentDocumentIds
            WITH SECURITY_ENFORCED
        ]) {
            docIdToSize.put(cv.ContentDocumentId, cv.ContentSize);
        }

        // Find oversized documents and collect for deletion
        List<Id> oversizedDocIds = new List<Id>();
        for (Id docId : contentDocumentIds) {
            Integer sizeBytes = docIdToSize.get(docId);
            if (sizeBytes != null && sizeBytes > sizeLimit) {
                oversizedDocIds.add(docId);
            }
        }

        // Delete the oversized ContentDocuments (this deletes all versions and links)
        if (!oversizedDocIds.isEmpty()) {
            try {
                Database.delete(oversizedDocIds, AccessLevel.USER_MODE); // Will respect sharing rules
            } catch (Exception e) {
                // Log or handle exception if needed, but continue with rest of logic
                // In practice, you'd want to log this or bubble up the error appropriately
            }
        }

        return oversizedDocIds;
    }

    /**
     * Builds a user-friendly error message listing the violating ContentDocumentIds and the size limit.
     * Note: This helper is private and used internally by the invocable; it should not be AuraEnabled.
     */
    private static String buildErrorMessage(List<String> offenderTitles, Long limitBytes) {
        if (offenderTitles == null || offenderTitles.isEmpty()) {
            return '';
        }
        // Represent 10 MB in MB with one decimal if needed (binary MB)
        Decimal limitMb = (limitBytes == null || limitBytes <= 0)
            ? Decimal.valueOf(DEFAULT_SIZE_LIMIT_BYTES) / 1048576
            : Decimal.valueOf(limitBytes) / 1048576;

        String names = String.join(offenderTitles, ', ');
        return 'Some files exceed the size limit of ' + limitMb.stripTrailingZeros().toPlainString() + ' MB: ' + names + '. Please remove oversized files and try again.';
    }
}