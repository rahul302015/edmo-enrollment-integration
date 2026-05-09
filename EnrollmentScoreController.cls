public with sharing class EnrollmentScoreController {
    public class EnrollmentScoreView {
        @AuraEnabled public Decimal score;
        @AuraEnabled public String recommendedAction;
        @AuraEnabled public String sourceSystem;
        @AuraEnabled public Datetime scoredAt;
        @AuraEnabled public String priority;
    }

    @AuraEnabled(cacheable=true)
    public static EnrollmentScoreView getLatestScore(Id contactId) {
        if (contactId == null) {
            return null;
        }

        enforceReadAccess();

        List<Enrollment_Score__c> scores = [
            SELECT Score__c, Recommended_Action__c, Source_System__c, Scored_At__c
            FROM Enrollment_Score__c
            WHERE Contact__c = :contactId
            ORDER BY Scored_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];

        if (scores.isEmpty()) {
            return null;
        }

        List<SObject> stripped = Security.stripInaccessible(
            AccessType.READABLE,
            scores
        ).getRecords();

        Enrollment_Score__c latest = (Enrollment_Score__c) stripped[0];

        EnrollmentScoreView view = new EnrollmentScoreView();
        view.score = latest.Score__c;
        view.recommendedAction = latest.Recommended_Action__c;
        view.sourceSystem = latest.Source_System__c;
        view.scoredAt = latest.Scored_At__c;
        view.priority = EnrollmentScoreTriggerHandler.derivePriority(latest.Score__c);
        return view;
    }

    private static void enforceReadAccess() {
        if (!Schema.sObjectType.Enrollment_Score__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to enrollment scores.');
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Enrollment_Score__c.fields.getMap();
        List<String> requiredFields = new List<String>{
            'Score__c',
            'Recommended_Action__c',
            'Source_System__c',
            'Scored_At__c'
        };

        for (String fieldName : requiredFields) {
            if (!fieldsMap.get(fieldName).getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have access to one or more enrollment score fields.');
            }
        }
    }
}