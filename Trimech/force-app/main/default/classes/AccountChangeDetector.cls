public class AccountChangeDetector {
    public static Boolean hasSignificantChanges(Account oldAcc, Account newAcc, Set<String> excludeFields) {
        Map<String, Object> oldMap = oldAcc.getPopulatedFieldsAsMap();
        Map<String, Object> newMap = newAcc.getPopulatedFieldsAsMap();

        for (String field : newMap.keySet()) {
            if (excludeFields.contains(field)) {
                continue;
            }

            Object newVal = newMap.get(field);
            Object oldVal = oldMap.get(field);

            if (oldVal != newVal && (oldVal == null || !oldVal.equals(newVal))) {
                return true;
            }
        }
        return false;
    }
}