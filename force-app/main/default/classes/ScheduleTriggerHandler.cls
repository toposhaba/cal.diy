public with sharing class ScheduleTriggerHandler {

    public static void handleBeforeSave(List<Schedule__c> records) {
        for (Schedule__c schedule : records) {
            if (schedule.Owner_User__c == null && schedule.OwnerId != null) {
                schedule.Owner_User__c = schedule.OwnerId;
            }
        }
    }
}
