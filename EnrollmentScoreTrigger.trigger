trigger EnrollmentScoreTrigger on Enrollment_Score__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        EnrollmentScoreTriggerHandler.afterInsert(Trigger.new);
    }
}