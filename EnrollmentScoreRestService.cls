@RestResource(urlMapping='/enrollment-scores/*')
global with sharing class EnrollmentScoreRestService {
    global class ScoreRequest {
        public List<ScoreInput> scores;
    }

    global class ScoreInput {
        public String contactEmail;
        public Integer score;
        public String recommendedAction;
        public String sourceSystem;
        public Datetime scoredAt;
    }

    global class RecordResult {
        public String contactEmail;
        public Boolean success;
        public String message;
        public Id contactId;
        public Id enrollmentScoreId;
    }

    global class ApiResponse {
        public Boolean success;
        public Integer totalReceived;
        public Integer successCount;
        public Integer failureCount;
        public List<RecordResult> results;
    }

    private class PendingScore {
        Integer resultIndex;
        Contact contact;
        ScoreInput input;
        Enrollment_Score__c record;

        PendingScore(Integer resultIndex, Contact contact, ScoreInput input, Enrollment_Score__c record) {
            this.resultIndex = resultIndex;
            this.contact = contact;
            this.input = input;
            this.record = record;
        }
    }

    @HttpPost
    global static ApiResponse postScores() {
        ApiResponse response = new ApiResponse();
        response.successCount = 0;
        response.failureCount = 0;
        response.results = new List<RecordResult>();

        String rawBody = RestContext.request == null || RestContext.request.requestBody == null
            ? null
            : RestContext.request.requestBody.toString();

        if (String.isBlank(rawBody)) {
            setHttpStatus(400);
            response.success = false;
            response.totalReceived = 0;
            RecordResult rr = new RecordResult();
            rr.success = false;
            rr.message = 'Request body is required.';
            response.results.add(rr);
            response.failureCount = 1;
            return response;
        }

        ScoreRequest req;
        try {
            req = (ScoreRequest) JSON.deserialize(rawBody, ScoreRequest.class);
        } catch (Exception e) {
            setHttpStatus(400);
            response.success = false;
            response.totalReceived = 0;
            RecordResult rr = new RecordResult();
            rr.success = false;
            rr.message = 'Invalid JSON payload: ' + e.getMessage();
            response.results.add(rr);
            response.failureCount = 1;
            return response;
        }

        if (req == null || req.scores == null || req.scores.isEmpty()) {
            setHttpStatus(400);
            response.success = false;
            response.totalReceived = 0;
            RecordResult rr = new RecordResult();
            rr.success = false;
            rr.message = 'scores must contain at least one item.';
            response.results.add(rr);
            response.failureCount = 1;
            return response;
        }

        response.totalReceived = req.scores.size();

        Set<String> emails = new Set<String>();
        for (ScoreInput input : req.scores) {
            if (input != null && String.isNotBlank(input.contactEmail)) {
                emails.add(input.contactEmail.trim().toLowerCase());
            }
        }

        Map<String, Contact> contactByEmail = new Map<String, Contact>();
        if (!emails.isEmpty()) {
            for (Contact c : [
                SELECT Id, Email
                FROM Contact
                WHERE Email IN :emails
            ]) {
                if (c.Email != null) {
                    contactByEmail.put(c.Email.trim().toLowerCase(), c);
                }
            }
        }

        List<PendingScore> pending = new List<PendingScore>();

        for (Integer i = 0; i < req.scores.size(); i++) {
            ScoreInput input = req.scores[i];

            RecordResult result = new RecordResult();
            result.contactEmail = input == null ? null : input.contactEmail;
            result.success = false;
            response.results.add(result);

            if (input == null) {
                result.message = 'Score item is null.';
                response.failureCount++;
                continue;
            }

            if (String.isBlank(input.contactEmail)) {
                result.message = 'contactEmail is required.';
                response.failureCount++;
                continue;
            }

            String normalizedEmail = input.contactEmail.trim().toLowerCase();
            Contact matchedContact = contactByEmail.get(normalizedEmail);

            if (matchedContact == null) {
                result.message = 'Contact not found for email: ' + input.contactEmail;
                response.failureCount++;
                continue;
            }

            Enrollment_Score__c scoreRecord = new Enrollment_Score__c(
                Contact__c = matchedContact.Id,
                Score__c = input.score,
                Recommended_Action__c = input.recommendedAction,
                Source_System__c = input.sourceSystem,
                Scored_At__c = input.scoredAt
            );

            pending.add(new PendingScore(i, matchedContact, input, scoreRecord));
        }

        if (!pending.isEmpty()) {
            List<Enrollment_Score__c> toInsert = new List<Enrollment_Score__c>();
            for (PendingScore p : pending) {
                toInsert.add(p.record);
            }

            Database.SaveResult[] saveResults = Database.insert(toInsert, false);

            for (Integer i = 0; i < saveResults.size(); i++) {
                PendingScore p = pending[i];
                RecordResult result = response.results[p.resultIndex];

                if (saveResults[i].isSuccess()) {
                    result.success = true;
                    result.message = 'Inserted successfully.';
                    result.contactId = p.contact.Id;
                    result.enrollmentScoreId = saveResults[i].getId();
                    response.successCount++;
                } else {
                    result.success = false;
                    result.message = saveResults[i].getErrors()[0].getMessage();
                    response.failureCount++;
                }
            }
        }

        response.success = (response.failureCount == 0);
        return response;
    }

    private static void setHttpStatus(Integer code) {
        if (RestContext.response != null) {
            RestContext.response.statusCode = code;
        }
    }
}