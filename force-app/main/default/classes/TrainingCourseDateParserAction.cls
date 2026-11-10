public with sharing class TrainingCourseDateParserAction {
    public class Request {
        @InvocableVariable(required=true label='Training Course Date Text')
        public String sourceDate;
    }

    public class Response {
        @InvocableVariable(label='Parsed Course Date')
        public Date parsedDate;

        @InvocableVariable(label='Date Parsed Successfully')
        public Boolean parsedSuccessfully;
    }

    @InvocableMethod(
        label='Parse Training Course Date'
        description='Converts supported training-form date text into a Salesforce Date.'
    )
    public static List<Response> parseDates(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            Response response = new Response();
            response.parsedDate = parseDate(request == null ? null : request.sourceDate);
            response.parsedSuccessfully = response.parsedDate != null;
            responses.add(response);
        }
        return responses;
    }

    @TestVisible
    private static Date parseDate(String sourceDate) {
        if (String.isBlank(sourceDate)) {
            return null;
        }

        String value = sourceDate.trim();
        value = value.replaceAll(
            '(?i)^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\\s*,\\s*',
            ''
        );
        value = value.replaceAll('(?i)(\\d{1,2})(st|nd|rd|th)', '$1');
        value = value.replaceAll(
            '(?i)\\b(Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\\.',
            '$1'
        );

        Matcher matcher = Pattern.compile('^(\\d{4})-(\\d{1,2})-(\\d{1,2})$').matcher(value);
        if (matcher.matches()) {
            return newDate(matcher.group(1), matcher.group(2), matcher.group(3));
        }

        matcher = Pattern.compile('^(\\d{1,2})/(\\d{1,2})/(\\d{2}|\\d{4})$').matcher(value);
        if (matcher.matches()) {
            Integer year = Integer.valueOf(matcher.group(3));
            if (year < 100) {
                year += 2000;
            }
            return newDate(String.valueOf(year), matcher.group(1), matcher.group(2));
        }

        matcher = Pattern.compile('^([A-Za-z]+)\\s+(\\d{1,2})\\s*,?\\s*(\\d{4})$').matcher(value);
        if (matcher.matches()) {
            Integer month = monthNumber(matcher.group(1));
            return month == null
                ? null
                : newDate(matcher.group(3), String.valueOf(month), matcher.group(2));
        }

        matcher = Pattern.compile('^(\\d{1,2})\\s+([A-Za-z]+)\\s*,?\\s*(\\d{4})$').matcher(value);
        if (matcher.matches()) {
            Integer month = monthNumber(matcher.group(2));
            return month == null
                ? null
                : newDate(matcher.group(3), String.valueOf(month), matcher.group(1));
        }

        return null;
    }

    private static Date newDate(String yearText, String monthText, String dayText) {
        try {
            Integer year = Integer.valueOf(yearText);
            Integer month = Integer.valueOf(monthText);
            Integer day = Integer.valueOf(dayText);
            Date parsedDate = Date.newInstance(year, month, day);
            return parsedDate.year() == year && parsedDate.month() == month && parsedDate.day() == day
                ? parsedDate
                : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Integer monthNumber(String monthText) {
        if (String.isBlank(monthText)) {
            return null;
        }

        Map<String, Integer> months = new Map<String, Integer>{
            'jan' => 1, 'january' => 1,
            'feb' => 2, 'february' => 2,
            'mar' => 3, 'march' => 3,
            'apr' => 4, 'april' => 4,
            'may' => 5,
            'jun' => 6, 'june' => 6,
            'jul' => 7, 'july' => 7,
            'aug' => 8, 'august' => 8,
            'sep' => 9, 'sept' => 9, 'september' => 9,
            'oct' => 10, 'october' => 10,
            'nov' => 11, 'november' => 11,
            'dec' => 12, 'december' => 12
        };
        return months.get(monthText.toLowerCase());
    }
}
