public with sharing class RecurringBookingService {

    private static final Integer MAX_OCCURRENCES = 52;

    public static List<Booking__c> createRecurringSeries(RecurringBookingRequest request) {
        validateRequest(request);

        List<Event_Type__c> eventTypes = [
            SELECT Id, Name, Duration_Minutes__c, Min_Booking_Notice_Minutes__c,
                   Owner_User__c, Location__c, Requires_Confirmation__c, Is_Active__c
            FROM Event_Type__c
            WHERE Id = :request.eventTypeId AND Is_Active__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventTypes.isEmpty()) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found or inactive');
        }
        Event_Type__c eventType = eventTypes[0];

        Recurring_Pattern__c pattern = new Recurring_Pattern__c(
            Frequency__c = request.frequency,
            Occurrences__c = request.occurrences,
            End_Date__c = request.seriesEndDate,
            Event_Type__c = eventType.Id
        );
        insert as user pattern;

        List<Datetime> scheduledTimes = calculateOccurrences(request);
        List<Booking__c> bookings = new List<Booking__c>();
        String status = eventType.Requires_Confirmation__c ? 'Pending' : 'Accepted';
        Integer durationMinutes = (Integer)eventType.Duration_Minutes__c;

        for (Datetime startDt : scheduledTimes) {
            bookings.add(new Booking__c(
                UID__c = generateUID(),
                Event_Type__c = eventType.Id,
                Host__c = eventType.Owner_User__c,
                Title__c = eventType.Name + ' with ' + String.escapeSingleQuotes(request.bookerName),
                Start_DateTime__c = startDt,
                End_DateTime__c = startDt.addMinutes(durationMinutes),
                Status__c = status,
                Location__c = eventType.Location__c,
                Booker_Email__c = request.bookerEmail,
                Booker_Name__c = request.bookerName,
                Recurring_Pattern__c = pattern.Id
            ));
        }

        insert as user bookings;
        return bookings;
    }

    public static void cancelRecurringSeries(Id recurringPatternId, String reason, Boolean futureOnly) {
        Datetime cutoff = futureOnly ? Datetime.now() : Datetime.newInstance(1970, 1, 1);

        List<Booking__c> bookings = [
            SELECT Id, Status__c, Start_DateTime__c
            FROM Booking__c
            WHERE Recurring_Pattern__c = :recurringPatternId
                AND Status__c IN ('Accepted', 'Pending')
                AND Start_DateTime__c >= :cutoff
            WITH USER_MODE
        ];

        for (Booking__c booking : bookings) {
            booking.Status__c = 'Cancelled';
            booking.Cancellation_Reason__c = reason;
        }

        if (!bookings.isEmpty()) {
            update as user bookings;
        }
    }

    public static List<Booking__c> getSeriesBookings(Id recurringPatternId) {
        return [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Location__c, Booker_Email__c, Booker_Name__c
            FROM Booking__c
            WHERE Recurring_Pattern__c = :recurringPatternId
            WITH USER_MODE
            ORDER BY Start_DateTime__c ASC
        ];
    }

    private static List<Datetime> calculateOccurrences(RecurringBookingRequest request) {
        List<Datetime> times = new List<Datetime>();
        Datetime current = request.firstStartDateTime;
        Integer maxOccurrences = request.occurrences != null ? Math.min(request.occurrences, MAX_OCCURRENCES) : MAX_OCCURRENCES;

        for (Integer i = 0; i < maxOccurrences; i++) {
            if (request.seriesEndDate != null && current.date() > request.seriesEndDate) {
                break;
            }
            times.add(current);
            current = getNextOccurrence(current, request.frequency);
        }

        return times;
    }

    private static Datetime getNextOccurrence(Datetime current, String frequency) {
        switch on frequency {
            when 'Daily' {
                return current.addDays(1);
            }
            when 'Weekly' {
                return current.addDays(7);
            }
            when 'Biweekly' {
                return current.addDays(14);
            }
            when 'Monthly' {
                return current.addMonths(1);
            }
            when else {
                return current.addDays(7);
            }
        }
    }

    private static void validateRequest(RecurringBookingRequest request) {
        if (request.eventTypeId == null) {
            throw new SchedulingException('INVALID_INPUT', 'Event type is required');
        }
        if (request.firstStartDateTime == null) {
            throw new SchedulingException('INVALID_INPUT', 'First start time is required');
        }
        if (String.isBlank(request.bookerEmail)) {
            throw new SchedulingException('INVALID_INPUT', 'Booker email is required');
        }
        if (String.isBlank(request.bookerName)) {
            throw new SchedulingException('INVALID_INPUT', 'Booker name is required');
        }
        if (String.isBlank(request.frequency)) {
            throw new SchedulingException('INVALID_INPUT', 'Frequency is required');
        }
        if (request.occurrences == null && request.seriesEndDate == null) {
            throw new SchedulingException('INVALID_INPUT', 'Either occurrences or series end date is required');
        }
        if (request.occurrences != null && request.occurrences > MAX_OCCURRENCES) {
            throw new SchedulingException('INVALID_INPUT', 'Maximum ' + MAX_OCCURRENCES + ' occurrences allowed');
        }
    }

    private static String generateUID() {
        Blob randomBytes = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' + hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }

    public class RecurringBookingRequest {
        @AuraEnabled public Id eventTypeId { get; set; }
        @AuraEnabled public Datetime firstStartDateTime { get; set; }
        @AuraEnabled public String bookerEmail { get; set; }
        @AuraEnabled public String bookerName { get; set; }
        @AuraEnabled public String frequency { get; set; }
        @AuraEnabled public Integer occurrences { get; set; }
        @AuraEnabled public Date seriesEndDate { get; set; }
    }
}
