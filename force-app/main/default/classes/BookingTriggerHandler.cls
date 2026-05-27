public with sharing class BookingTriggerHandler {

    public static void handleAfterInsert(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        if (Trigger.isInsert) {
            processNewBookings(newBookings);
        } else if (Trigger.isUpdate) {
            processUpdatedBookings(newBookings, oldMap);
        }
    }

    private static void processNewBookings(List<Booking__c> newBookings) {
        List<Id> confirmedIds = new List<Id>();
        List<Id> pendingIds = new List<Id>();
        List<Booking_Event__e> events = new List<Booking_Event__e>();

        for (Booking__c booking : newBookings) {
            if (booking.Status__c == 'Accepted') {
                confirmedIds.add(booking.Id);
            } else if (booking.Status__c == 'Pending') {
                pendingIds.add(booking.Id);
            }

            events.add(new Booking_Event__e(
                Booking_Id__c = booking.Id,
                Action__c = 'Created',
                Status__c = booking.Status__c
            ));
        }

        if (!confirmedIds.isEmpty()) {
            BookingNotificationService.sendBookingConfirmation(confirmedIds);
            syncToExternalCalendars(confirmedIds);
        }

        if (!pendingIds.isEmpty()) {
            BookingNotificationService.sendPendingApprovalNotice(pendingIds);
        }

        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    private static void processUpdatedBookings(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        List<Id> newlyConfirmedIds = new List<Id>();
        List<Id> cancelledIds = new List<Id>();
        List<Id> rescheduledIds = new List<Id>();
        List<Booking_Event__e> events = new List<Booking_Event__e>();

        for (Booking__c booking : newBookings) {
            Booking__c oldBooking = oldMap.get(booking.Id);

            if (oldBooking.Status__c == 'Pending' && booking.Status__c == 'Accepted') {
                newlyConfirmedIds.add(booking.Id);
                events.add(new Booking_Event__e(
                    Booking_Id__c = booking.Id,
                    Action__c = 'Confirmed',
                    Status__c = booking.Status__c
                ));
            }

            if (oldBooking.Status__c != 'Cancelled' && booking.Status__c == 'Cancelled') {
                cancelledIds.add(booking.Id);
                events.add(new Booking_Event__e(
                    Booking_Id__c = booking.Id,
                    Action__c = 'Cancelled',
                    Status__c = booking.Status__c
                ));
            }

            if (booking.Status__c != 'Cancelled' &&
                (oldBooking.Start_DateTime__c != booking.Start_DateTime__c ||
                 oldBooking.End_DateTime__c != booking.End_DateTime__c)) {
                rescheduledIds.add(booking.Id);
                events.add(new Booking_Event__e(
                    Booking_Id__c = booking.Id,
                    Action__c = 'Rescheduled',
                    Status__c = booking.Status__c
                ));
            }
        }

        if (!newlyConfirmedIds.isEmpty()) {
            BookingNotificationService.sendBookingConfirmation(newlyConfirmedIds);
            syncToExternalCalendars(newlyConfirmedIds);
        }

        if (!cancelledIds.isEmpty()) {
            BookingNotificationService.sendCancellationNotice(cancelledIds);
            removeFromExternalCalendars(cancelledIds);
        }

        if (!rescheduledIds.isEmpty()) {
            BookingNotificationService.sendRescheduleNotice(rescheduledIds);
            removeFromExternalCalendars(rescheduledIds);
            syncToExternalCalendars(rescheduledIds);
        }

        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    @future(callout=true)
    private static void syncToExternalCalendars(List<Id> bookingIds) {
        for (Id bookingId : bookingIds) {
            try {
                CalendarIntegrationService.createExternalEvent(bookingId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Calendar sync failed for booking ' + bookingId + ': ' + e.getMessage());
            }
        }
    }

    @future(callout=true)
    private static void removeFromExternalCalendars(List<Id> bookingIds) {
        for (Id bookingId : bookingIds) {
            try {
                CalendarIntegrationService.deleteExternalEvent(bookingId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Calendar event deletion failed for booking ' + bookingId + ': ' + e.getMessage());
            }
        }
    }
}
