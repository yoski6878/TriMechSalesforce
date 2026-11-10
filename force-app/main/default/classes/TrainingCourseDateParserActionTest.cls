@IsTest
private class TrainingCourseDateParserActionTest {
    @IsTest
    static void parsesSupportedUatFormats() {
        Map<String, Date> examples = new Map<String, Date>{
            'June 15, 2026' => Date.newInstance(2026, 6, 15),
            'Monday, 6th July, 2026' => Date.newInstance(2026, 7, 6),
            'Monday, 29th July, 2024' => Date.newInstance(2024, 7, 29),
            '05/08/2023' => Date.newInstance(2023, 5, 8),
            '5/22/23' => Date.newInstance(2023, 5, 22),
            'Feb. 2, 2025' => Date.newInstance(2025, 2, 2),
            '2026-11-20' => Date.newInstance(2026, 11, 20)
        };

        for (String sourceValue : examples.keySet()) {
            Assert.areEqual(
                examples.get(sourceValue),
                TrainingCourseDateParserAction.parseDate(sourceValue),
                'Unexpected parsed date for ' + sourceValue
            );
        }
    }

    @IsTest
    static void returnsNullForBlankInvalidAndImpossibleDates() {
        List<String> invalidValues = new List<String>{
            null,
            '',
            'To be scheduled',
            'February 30, 2026',
            '13/40/2026'
        };

        for (String sourceValue : invalidValues) {
            Assert.isNull(
                TrainingCourseDateParserAction.parseDate(sourceValue),
                'Invalid date should not parse: ' + sourceValue
            );
        }
    }

    @IsTest
    static void invocableReturnsOneResultPerRequest() {
        TrainingCourseDateParserAction.Request validRequest =
            new TrainingCourseDateParserAction.Request();
        validRequest.sourceDate = 'October 29, 2026';

        TrainingCourseDateParserAction.Request invalidRequest =
            new TrainingCourseDateParserAction.Request();
        invalidRequest.sourceDate = 'Unknown';

        List<TrainingCourseDateParserAction.Response> responses =
            TrainingCourseDateParserAction.parseDates(
                new List<TrainingCourseDateParserAction.Request>{ validRequest, invalidRequest }
            );

        Assert.areEqual(2, responses.size());
        Assert.areEqual(Date.newInstance(2026, 10, 29), responses[0].parsedDate);
        Assert.isTrue(responses[0].parsedSuccessfully);
        Assert.isNull(responses[1].parsedDate);
        Assert.isFalse(responses[1].parsedSuccessfully);
    }
}
