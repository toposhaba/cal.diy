trigger BookingTrigger on Booking__c (after insert, after update) {
    BookingTriggerHandler.handleAfterInsert(Trigger.new, Trigger.oldMap);
}
