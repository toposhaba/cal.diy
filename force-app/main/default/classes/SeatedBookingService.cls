public with sharing class SeatedBookingService {

    public static Booking_Seat__c reserveSeat(Id bookingId, String attendeeName, String attendeeEmail) {
        Booking__c booking = [
            SELECT Id, Event_Type__c, Event_Type__r.Seats_Per_Slot__c, Start_DateTime__c, End_DateTime__c
            FROM Booking__c
            WHERE Id = :bookingId AND Status__c = 'Accepted'
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Active booking not found');
        }

        Integer maxSeats = booking.Event_Type__r.Seats_Per_Slot__c != null
            ? (Integer) booking.Event_Type__r.Seats_Per_Slot__c : 1;

        Integer currentSeats = [
            SELECT COUNT()
            FROM Booking_Seat__c
            WHERE Booking__c = :bookingId AND Status__c = 'Reserved'
            WITH USER_MODE
        ];

        if (currentSeats >= maxSeats) {
            throw new SchedulingException('SEATS_FULL', 'No seats remaining for this time slot');
        }

        Attendee__c attendee = new Attendee__c(
            Booking__c = bookingId,
            Name = attendeeName,
            Email__c = attendeeEmail
        );
        insert as user attendee;

        Booking_Seat__c seat = new Booking_Seat__c(
            Booking__c = bookingId,
            Attendee__c = attendee.Id,
            Status__c = 'Reserved'
        );
        insert as user seat;

        return seat;
    }

    public static void cancelSeat(Id seatId) {
        Booking_Seat__c seat = [
            SELECT Id, Status__c
            FROM Booking_Seat__c
            WHERE Id = :seatId AND Status__c = 'Reserved'
            WITH USER_MODE
            LIMIT 1
        ];

        if (seat == null) {
            throw new SchedulingException('SEAT_NOT_FOUND', 'Active seat reservation not found');
        }

        seat.Status__c = 'Cancelled';
        update as user seat;
    }

    public static Integer getAvailableSeats(Id bookingId) {
        Booking__c booking = [
            SELECT Id, Event_Type__r.Seats_Per_Slot__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) return 0;

        Integer maxSeats = booking.Event_Type__r.Seats_Per_Slot__c != null
            ? (Integer) booking.Event_Type__r.Seats_Per_Slot__c : 1;

        Integer reservedSeats = [
            SELECT COUNT()
            FROM Booking_Seat__c
            WHERE Booking__c = :bookingId AND Status__c = 'Reserved'
            WITH USER_MODE
        ];

        return maxSeats - reservedSeats;
    }

    public static Booking__c findOrCreateSeatedBooking(
        Id eventTypeId, Id hostUserId, Datetime slotStart, String bookerName, String bookerEmail
    ) {
        Event_Type__c eventType = [
            SELECT Id, Name, Duration_Minutes__c, Seats_Per_Slot__c, Owner_User__c, Location__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId AND Is_Active__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventType == null) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found');
        }

        Datetime slotEnd = slotStart.addMinutes((Integer) eventType.Duration_Minutes__c);

        List<Booking__c> existingBookings = [
            SELECT Id
            FROM Booking__c
            WHERE Event_Type__c = :eventTypeId
                AND Start_DateTime__c = :slotStart
                AND End_DateTime__c = :slotEnd
                AND Status__c = 'Accepted'
            WITH USER_MODE
            LIMIT 1
        ];

        if (!existingBookings.isEmpty()) {
            return existingBookings[0];
        }

        Booking__c newBooking = new Booking__c(
            UID__c = generateUID(),
            Event_Type__c = eventType.Id,
            Host__c = hostUserId,
            Title__c = eventType.Name + ' with ' + String.escapeSingleQuotes(bookerName),
            Start_DateTime__c = slotStart,
            End_DateTime__c = slotEnd,
            Status__c = 'Accepted',
            Location__c = eventType.Location__c,
            Booker_Email__c = bookerEmail,
            Booker_Name__c = bookerName
        );
        insert as user newBooking;
        return newBooking;
    }

    public static Integer getAvailableSeatsForSlot(Id eventTypeId, Datetime slotStart, Datetime slotEnd) {
        List<Event_Type__c> eventTypes = [
            SELECT Seats_Per_Slot__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventTypes.isEmpty()) {
            return 0;
        }

        Integer maxSeats = eventTypes[0].Seats_Per_Slot__c != null
            ? (Integer) eventTypes[0].Seats_Per_Slot__c : 1;

        if (maxSeats <= 1) {
            return maxSeats;
        }

        List<Booking__c> existingBookings = [
            SELECT Id
            FROM Booking__c
            WHERE Event_Type__c = :eventTypeId
                AND Start_DateTime__c = :slotStart
                AND End_DateTime__c = :slotEnd
                AND Status__c = 'Accepted'
            WITH USER_MODE
            LIMIT 1
        ];

        if (existingBookings.isEmpty()) {
            return maxSeats;
        }

        return getAvailableSeats(existingBookings[0].Id);
    }

    public static List<AvailabilityService.TimeSlot> enrichSlotsWithSeatAvailability(
        Id eventTypeId, List<AvailabilityService.TimeSlot> slots
    ) {
        List<Event_Type__c> eventTypes = [
            SELECT Seats_Per_Slot__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventTypes.isEmpty()) {
            return slots;
        }

        Integer maxSeats = eventTypes[0].Seats_Per_Slot__c != null
            ? (Integer) eventTypes[0].Seats_Per_Slot__c : 1;

        if (maxSeats <= 1) {
            return slots;
        }

        List<AvailabilityService.TimeSlot> availableSlots = new List<AvailabilityService.TimeSlot>();
        for (AvailabilityService.TimeSlot slot : slots) {
            Integer remaining = getAvailableSeatsForSlot(eventTypeId, slot.startTime, slot.endTime);
            slot.availableSeats = remaining;
            if (remaining > 0) {
                availableSlots.add(slot);
            }
        }
        return availableSlots;
    }

    public static Boolean isSeatedEvent(Event_Type__c eventType) {
        return eventType.Seats_Per_Slot__c != null && eventType.Seats_Per_Slot__c > 1;
    }

    private static String generateUID() {
        Blob randomBytes = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' + hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }
}
