public with sharing class IcsGenerator {

    public static String generateIcsContent(Id bookingId) {
        Booking__c booking = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Location__c, Booker_Email__c, Booker_Name__c,
                   Host__r.Name, Host__r.Email,
                   Event_Type__r.Description__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) return null;

        String ics = 'BEGIN:VCALENDAR\r\n';
        ics += 'VERSION:2.0\r\n';
        ics += 'PRODID:-//Salesforce Scheduling//EN\r\n';
        ics += 'CALSCALE:GREGORIAN\r\n';
        ics += 'METHOD:REQUEST\r\n';
        ics += 'BEGIN:VEVENT\r\n';
        ics += 'UID:' + booking.UID__c + '@salesforce-scheduling\r\n';
        ics += 'DTSTART:' + formatIcsDateTime(booking.Start_DateTime__c) + '\r\n';
        ics += 'DTEND:' + formatIcsDateTime(booking.End_DateTime__c) + '\r\n';
        ics += 'DTSTAMP:' + formatIcsDateTime(Datetime.now()) + '\r\n';
        ics += 'SUMMARY:' + escapeIcs(booking.Title__c) + '\r\n';

        if (String.isNotBlank(booking.Location__c)) {
            ics += 'LOCATION:' + escapeIcs(booking.Location__c) + '\r\n';
        }

        if (String.isNotBlank(booking.Event_Type__r.Description__c)) {
            ics += 'DESCRIPTION:' + escapeIcs(booking.Event_Type__r.Description__c) + '\r\n';
        }

        ics += 'ORGANIZER;CN=' + escapeIcs(booking.Host__r.Name) + ':mailto:' + booking.Host__r.Email + '\r\n';
        ics += 'ATTENDEE;CN=' + escapeIcs(booking.Booker_Name__c) + ';RSVP=TRUE:mailto:' + booking.Booker_Email__c + '\r\n';
        ics += 'STATUS:CONFIRMED\r\n';
        ics += 'SEQUENCE:0\r\n';
        ics += 'END:VEVENT\r\n';
        ics += 'END:VCALENDAR\r\n';

        return ics;
    }

    public static Messaging.EmailFileAttachment createIcsAttachment(Id bookingId) {
        String icsContent = generateIcsContent(bookingId);
        if (String.isBlank(icsContent)) return null;

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('invite.ics');
        attachment.setBody(Blob.valueOf(icsContent));
        attachment.setContentType('text/calendar; method=REQUEST');
        return attachment;
    }

    private static String formatIcsDateTime(Datetime dt) {
        return dt.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
    }

    private static String escapeIcs(String input) {
        if (String.isBlank(input)) return '';
        return input
            .replace('\\', '\\\\')
            .replace(';', '\\;')
            .replace(',', '\\,')
            .replace('\n', '\\n')
            .replace('\r', '');
    }
}
