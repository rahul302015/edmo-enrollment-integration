public class EnrollmentScoreTriggerHandler {
    public static void afterInsert(List<Enrollment_Score__c> newScores) {
        if (newScores == null || newScores.isEmpty()) {
            return;
        }

        Map<Id, Enrollment_Score__c> latestByContact = new Map<Id, Enrollment_Score__c>();

        for (Enrollment_Score__c score : newScores) {
            if (score.Contact__c == null) {
                continue;
            }

            Enrollment_Score__c existing = latestByContact.get(score.Contact__c);
            if (existing == null || isNewer(score, existing)) {
                latestByContact.put(score.Contact__c, score);
            }
        }

        if (latestByContact.isEmpty()) {
            return;
        }

        List<Contact> contactsToUpdate = new List<Contact>();
        for (Id contactId : latestByContact.keySet()) {
            Enrollment_Score__c latestScore = latestByContact.get(contactId);
            contactsToUpdate.add(new Contact(
                Id = contactId,
                Enrollment_Priority__c = derivePriority(latestScore.Score__c)
            ));
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    @TestVisible
    public static String derivePriority(Decimal score) {
        if (score == null) {
            return 'Cold';
        }
        if (score >= 75) {
            return 'Hot';
        }
        if (score >= 40) {
            return 'Warm';
        }
        return 'Cold';
    }

    private static Boolean isNewer(Enrollment_Score__c candidate, Enrollment_Score__c current) {
        if (current == null) {
            return true;
        }
        if (candidate.Scored_At__c == null && current.Scored_At__c == null) {
            return false;
        }
        if (candidate.Scored_At__c == null) {
            return false;
        }
        if (current.Scored_At__c == null) {
            return true;
        }
        if (candidate.Scored_At__c.getTime() != current.Scored_At__c.getTime()) {
            return candidate.Scored_At__c.getTime() > current.Scored_At__c.getTime();
        }
        return true;
    }
}