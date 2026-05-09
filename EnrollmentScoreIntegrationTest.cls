@IsTest
private class EnrollmentScoreIntegrationTest {
    @testSetup
    static void setupData() {
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Jane', LastName = 'Doe', Email = 'jane.doe@example.com'),
            new Contact(FirstName = 'John', LastName = 'Smith', Email = 'john.smith@example.com'),
            new Contact(FirstName = 'Ava', LastName = 'Brown', Email = 'ava.brown@example.com'),
            new Contact(FirstName = 'Liam', LastName = 'Jones', Email = 'liam.jones@example.com'),
            new Contact(FirstName = 'Mia', LastName = 'Taylor', Email = 'mia.taylor@example.com')
        };
        insert contacts;
    }

    private static EnrollmentScoreRestService.ApiResponse callRest(List<Object> scoreItems) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/enrollment-scores/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'scores' => scoreItems
        }));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        return EnrollmentScoreRestService.postScores();
    }

    @IsTest
    static void testPositiveCaseValidEmailAndTriggerUpdate() {
        Contact jane = [SELECT Id, Email, Enrollment_Priority__c FROM Contact WHERE Email = 'jane.doe@example.com' LIMIT 1];

        List<Object> scores = new List<Object>{
            new Map<String, Object>{
                'contactEmail' => 'jane.doe@example.com',
                'score' => 85,
                'recommendedAction' => 'Schedule Call',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:30:00Z'
            }
        };

        Test.startTest();
        EnrollmentScoreRestService.ApiResponse res = callRest(scores);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals(1, res.totalReceived);
        System.assertEquals(1, res.successCount);
        System.assertEquals(0, res.failureCount);
        System.assertEquals(1, res.results.size());
        System.assertEquals(true, res.results[0].success);
        System.assertEquals('Inserted successfully.', res.results[0].message);

        jane = [SELECT Enrollment_Priority__c FROM Contact WHERE Id = :jane.Id];
        System.assertEquals('Hot', jane.Enrollment_Priority__c);

        List<Enrollment_Score__c> inserted = [
            SELECT Contact__c, Score__c, Recommended_Action__c, Source_System__c
            FROM Enrollment_Score__c
            WHERE Contact__c = :jane.Id
        ];
        System.assertEquals(1, inserted.size());
        System.assertEquals(85, inserted[0].Score__c);
        System.assertEquals('Schedule Call', inserted[0].Recommended_Action__c);
        System.assertEquals('EDMO Bot v2', inserted[0].Source_System__c);
    }

    @IsTest
    static void testNegativeCaseEmailNotFound() {
        List<Object> scores = new List<Object>{
            new Map<String, Object>{
                'contactEmail' => 'missing.person@example.com',
                'score' => 42,
                'recommendedAction' => 'Send Info Pack',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:31:00Z'
            }
        };

        Test.startTest();
        EnrollmentScoreRestService.ApiResponse res = callRest(scores);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(1, res.totalReceived);
        System.assertEquals(0, res.successCount);
        System.assertEquals(1, res.failureCount);
        System.assertEquals(1, res.results.size());
        System.assertEquals(false, res.results[0].success);
        System.assert(res.results[0].message.contains('Contact not found'));

        System.assertEquals(0, [SELECT COUNT() FROM Enrollment_Score__c WHERE Source_System__c = 'EDMO Bot v2']);
    }

    @IsTest
    static void testBulkCaseFivePlusRecordsAndLatestWins() {
        List<Object> scores = new List<Object>{
            new Map<String, Object>{
                'contactEmail' => 'jane.doe@example.com',
                'score' => 30,
                'recommendedAction' => 'Send Info Pack',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T09:00:00Z'
            },
            new Map<String, Object>{
                'contactEmail' => 'jane.doe@example.com',
                'score' => 95,
                'recommendedAction' => 'Mark Hot Lead',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T11:00:00Z'
            },
            new Map<String, Object>{
                'contactEmail' => 'john.smith@example.com',
                'score' => 20,
                'recommendedAction' => 'Assign Counselor',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:35:00Z'
            },
            new Map<String, Object>{
                'contactEmail' => 'ava.brown@example.com',
                'score' => 74,
                'recommendedAction' => 'Schedule Call',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:36:00Z'
            },
            new Map<String, Object>{
                'contactEmail' => 'liam.jones@example.com',
                'score' => 75,
                'recommendedAction' => 'Mark Hot Lead',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:37:00Z'
            },
            new Map<String, Object>{
                'contactEmail' => 'mia.taylor@example.com',
                'score' => 39,
                'recommendedAction' => 'Send Info Pack',
                'sourceSystem' => 'EDMO Bot v2',
                'scoredAt' => '2026-03-10T10:38:00Z'
            }
        };

        Test.startTest();
        EnrollmentScoreRestService.ApiResponse res = callRest(scores);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals(6, res.totalReceived);
        System.assertEquals(6, res.successCount);
        System.assertEquals(0, res.failureCount);
        System.assertEquals(6, res.results.size());

        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Contact c : [
            SELECT Id, Email, Enrollment_Priority__c
            FROM Contact
            WHERE Email IN ('jane.doe@example.com', 'john.smith@example.com', 'ava.brown@example.com', 'liam.jones@example.com', 'mia.taylor@example.com')
        ]) {
            contactsByEmail.put(c.Email.toLowerCase(), c);
        }

        System.assertEquals('Hot', contactsByEmail.get('jane.doe@example.com').Enrollment_Priority__c);
        System.assertEquals('Cold', contactsByEmail.get('john.smith@example.com').Enrollment_Priority__c);
        System.assertEquals('Warm', contactsByEmail.get('ava.brown@example.com').Enrollment_Priority__c);
        System.assertEquals('Hot', contactsByEmail.get('liam.jones@example.com').Enrollment_Priority__c);
        System.assertEquals('Cold', contactsByEmail.get('mia.taylor@example.com').Enrollment_Priority__c);

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Enrollment_Score__c WHERE Contact__c = :contactsByEmail.get('jane.doe@example.com').Id]
        );
    }
}