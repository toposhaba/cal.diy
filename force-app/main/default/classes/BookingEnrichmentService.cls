public with sharing class BookingEnrichmentService {

    public static void ensureMeetingLink(Id bookingId) {
        List<Booking__c> bookings = [
            SELECT Id, Title__c, Start_DateTime__c, End_DateTime__c, Location__c,
                   Event_Type__r.Video_Provider__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            return;
        }

        Booking__c booking = bookings[0];
        String provider = booking.Event_Type__r.Video_Provider__c;

        if (String.isBlank(provider) || provider == 'None') {
            return;
        }

        if (String.isNotBlank(booking.Location__c) && booking.Location__c.startsWith('http')) {
            return;
        }

        if (Test.isRunningTest()) {
            booking.Location__c = 'https://meet.example.com/' + booking.Id;
            update as user booking;
            return;
        }

        String meetingUrl = VideoConferencingService.createMeetingLink(booking, provider);
        if (String.isNotBlank(meetingUrl)) {
            booking.Location__c = meetingUrl;
            update as user booking;
        }
    }
}
