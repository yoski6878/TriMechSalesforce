public with sharing class BusinessHoursCalculator {
    @InvocableMethod(label='Calculate Business Hours DateTime')
    public static List<DateTimeResult> calculate(List<InputParams> inputs) {
        List<DateTimeResult> results = new List<DateTimeResult>();
        for (InputParams input : inputs) {
            // Use provided Business Hours ID
            Id bhId = '01mO4000004CxJlIAK';
            DateTime start = input.startDateTime;
            Integer offset = input.offsetHours;

            // Calculate target DateTime based on Business Hours
            DateTime target = BusinessHours.addGmt(bhId, start, offset * 60 * 60 * 1000);
            results.add(new DateTimeResult(target));
        }
        return results;
    }

    public class InputParams {
        @InvocableVariable(required=true)
        public DateTime startDateTime;
        @InvocableVariable(required=true)
        public Integer offsetHours;
    }

    public class DateTimeResult {
        @InvocableVariable
        public DateTime calculatedDateTime;
        public DateTimeResult(DateTime dt) {
            calculatedDateTime = dt;
        }
    }
}