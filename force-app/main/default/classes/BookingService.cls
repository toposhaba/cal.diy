public with sharing class BookingService {

    public static Booking__c createBooking(BookingRequest request) {
        validateBookingRequest(request);

        Event_Type__c eventType = [
            SELECT Id, Name, Duration_Minutes__c, Min_Booking_Notice_Minutes__c,
                   Buffer_Before_Minutes__c, Buffer_After_Minutes__c,
                   Owner_User__c, Location__c, Requires_Confirmation__c, Is_Active__c
            FROM Event_Type__c
            WHERE Id = :request.eventTypeId AND Is_Active__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventType == null) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found or inactive');
        }

        Datetime slotEnd = request.startDateTime.addMinutes((Integer)eventType.Duration_Minutes__c);
        validateSlotAvailability(eventType, request.startDateTime, slotEnd);

        String status = eventType.Requires_Confirmation__c ? 'Pending' : 'Accepted';

        Booking__c booking = new Booking__c(
            UID__c = generateUID(),
            Event_Type__c = eventType.Id,
            Host__c = eventType.Owner_User__c,
            Title__c = eventType.Name + ' with ' + String.escapeSingleQuotes(request.bookerName),
            Start_DateTime__c = request.startDateTime,
            End_DateTime__c = slotEnd,
            Status__c = status,
            Location__c = eventType.Location__c,
            Booker_Email__c = request.bookerEmail,
            Booker_Name__c = request.bookerName
        );

        insert as user booking;

        if (request.attendeeEmails != null && !request.attendeeEmails.isEmpty()) {
            createAttendees(booking.Id, request.attendeeEmails, request.bookerName);
        }

        return booking;
    }

    public static Booking__c cancelBooking(Id bookingId, String reason) {
        Booking__c booking = [
            SELECT Id, Status__c, Host__c, Start_DateTime__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Booking not found');
        }

        if (booking.Status__c == 'Cancelled') {
            throw new SchedulingException('ALREADY_CANCELLED', 'Booking is already cancelled');
        }

        booking.Status__c = 'Cancelled';
        booking.Cancellation_Reason__c = reason;
        update as user booking;
        return booking;
    }

    public static Booking__c confirmBooking(Id bookingId) {
        Booking__c booking = [
            SELECT Id, Status__c, Host__c
            FROM Booking__c
            WHERE Id = :bookingId AND Status__c = 'Pending'
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Pending booking not found');
        }

        booking.Status__c = 'Accepted';
        update as user booking;
        return booking;
    }

    public static Booking__c rescheduleBooking(Id bookingId, Datetime newStartDateTime) {
        Booking__c existingBooking = [
            SELECT Id, Status__c, Event_Type__c, Host__c,
                   Event_Type__r.Duration_Minutes__c,
                   Event_Type__r.Min_Booking_Notice_Minutes__c,
                   Event_Type__r.Buffer_Before_Minutes__c,
                   Event_Type__r.Buffer_After_Minutes__c,
                   Event_Type__r.Owner_User__c
            FROM Booking__c
            WHERE Id = :bookingId AND Status__c IN ('Accepted', 'Pending')
            WITH USER_MODE
            LIMIT 1
        ];

        if (existingBooking == null) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Active booking not found');
        }

        Event_Type__c eventType = new Event_Type__c(
            Id = existingBooking.Event_Type__c,
            Duration_Minutes__c = existingBooking.Event_Type__r.Duration_Minutes__c,
            Min_Booking_Notice_Minutes__c = existingBooking.Event_Type__r.Min_Booking_Notice_Minutes__c,
            Buffer_Before_Minutes__c = existingBooking.Event_Type__r.Buffer_Before_Minutes__c,
            Buffer_After_Minutes__c = existingBooking.Event_Type__r.Buffer_After_Minutes__c,
            Owner_User__c = existingBooking.Event_Type__r.Owner_User__c
        );

        Datetime newEnd = newStartDateTime.addMinutes((Integer)eventType.Duration_Minutes__c);
        validateSlotAvailability(eventType, newStartDateTime, newEnd);

        existingBooking.Start_DateTime__c = newStartDateTime;
        existingBooking.End_DateTime__c = newEnd;
        update as user existingBooking;
        return existingBooking;
    }

    public static List<Booking__c> getBookingsForHost(Id hostUserId, Date startDate, Date endDate) {
        return [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Location__c, Booker_Email__c, Booker_Name__c,
                   Event_Type__r.Name, Event_Type__r.Duration_Minutes__c
            FROM Booking__c
            WHERE Host__c = :hostUserId
                AND Start_DateTime__c >= :Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0))
                AND End_DateTime__c <= :Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0))
            WITH USER_MODE
            ORDER BY Start_DateTime__c ASC
        ];
    }

    private static void validateBookingRequest(BookingRequest request) {
        if (request.eventTypeId == null) {
            throw new SchedulingException('INVALID_INPUT', 'Event type is required');
        }
        if (request.startDateTime == null) {
            throw new SchedulingException('INVALID_INPUT', 'Start time is required');
        }
        if (String.isBlank(request.bookerEmail)) {
            throw new SchedulingException('INVALID_INPUT', 'Booker email is required');
        }
        if (String.isBlank(request.bookerName)) {
            throw new SchedulingException('INVALID_INPUT', 'Booker name is required');
        }
        if (!isValidEmail(request.bookerEmail)) {
            throw new SchedulingException('INVALID_INPUT', 'Invalid email format');
        }
    }

    private static void validateSlotAvailability(Event_Type__c eventType, Datetime slotStart, Datetime slotEnd) {
        Integer minNotice = eventType.Min_Booking_Notice_Minutes__c != null
            ? (Integer)eventType.Min_Booking_Notice_Minutes__c : 120;

        if (slotStart < Datetime.now().addMinutes(minNotice)) {
            throw new SchedulingException('INSUFFICIENT_NOTICE',
                'Booking must be made at least ' + minNotice + ' minutes in advance');
        }

        Integer bufferBefore = eventType.Buffer_Before_Minutes__c != null
            ? (Integer)eventType.Buffer_Before_Minutes__c : 0;
        Integer bufferAfter = eventType.Buffer_After_Minutes__c != null
            ? (Integer)eventType.Buffer_After_Minutes__c : 0;

        Datetime checkStart = slotStart.addMinutes(-bufferBefore);
        Datetime checkEnd = slotEnd.addMinutes(bufferAfter);

        List<Booking__c> conflicts = [
            SELECT Id
            FROM Booking__c
            WHERE Host__c = :eventType.Owner_User__c
                AND Status__c IN ('Accepted', 'Pending')
                AND Start_DateTime__c < :checkEnd
                AND End_DateTime__c > :checkStart
            WITH USER_MODE
            LIMIT 1
        ];

        if (!conflicts.isEmpty()) {
            throw new SchedulingException('SLOT_UNAVAILABLE', 'The selected time slot is no longer available');
        }
    }

    private static void createAttendees(Id bookingId, List<String> emails, String primaryName) {
        List<Attendee__c> attendees = new List<Attendee__c>();
        for (String email : emails) {
            if (String.isNotBlank(email) && isValidEmail(email)) {
                attendees.add(new Attendee__c(
                    Booking__c = bookingId,
                    Name = email.substringBefore('@'),
                    Email__c = email
                ));
            }
        }
        if (!attendees.isEmpty()) {
            insert as user attendees;
        }
    }

    private static Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$';
        Pattern emailPattern = Pattern.compile(emailRegex);
        Matcher emailMatcher = emailPattern.matcher(email);
        return emailMatcher.matches();
    }

    private static String generateUID() {
        Blob randomBytes = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' + hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }

    public class BookingRequest {
        @AuraEnabled public Id eventTypeId { get; set; }
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public String bookerEmail { get; set; }
        @AuraEnabled public String bookerName { get; set; }
        @AuraEnabled public List<String> attendeeEmails { get; set; }
    }
}
