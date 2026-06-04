public with sharing class AvailabilityService {

    public static List<Schedule__c> getSchedulesForUser(Id userId) {
        return [
            SELECT Id, Name, Time_Zone__c, Is_Default__c, Owner_User__c,
                (SELECT Id, Record_Type__c, Days__c, Start_Time__c, End_Time__c, Override_Date__c
                 FROM Availabilities__r
                 ORDER BY Start_Time__c ASC)
            FROM Schedule__c
            WHERE Owner_User__c = :userId
                OR (Owner_User__c = null AND OwnerId = :userId)
            WITH USER_MODE
            ORDER BY Is_Default__c DESC, Name ASC
        ];
    }

    public static Schedule__c getDefaultSchedule(Id userId) {
        List<Schedule__c> schedules = [
            SELECT Id, Name, Time_Zone__c, Is_Default__c, Owner_User__c,
                (SELECT Id, Record_Type__c, Days__c, Start_Time__c, End_Time__c, Override_Date__c
                 FROM Availabilities__r
                 ORDER BY Start_Time__c ASC)
            FROM Schedule__c
            WHERE (Owner_User__c = :userId OR (Owner_User__c = null AND OwnerId = :userId))
                AND Is_Default__c = true
            WITH USER_MODE
            LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return null;
        }
        return schedules[0];
    }

    public static List<Integer> resolveDurations(Event_Type__c eventType) {
        if (String.isNotBlank(eventType.Multiple_Durations__c)) {
            List<Integer> durations = new List<Integer>();
            for (String part : eventType.Multiple_Durations__c.split(',')) {
                String trimmed = part.trim();
                if (String.isNotBlank(trimmed)) {
                    durations.add(Integer.valueOf(trimmed));
                }
            }
            if (!durations.isEmpty()) {
                return durations;
            }
        }
        return new List<Integer>{ (Integer) eventType.Duration_Minutes__c };
    }

    public static List<TimeSlot> getAvailableSlots(Id eventTypeId, Date startDate, Date endDate) {
        return getAvailableSlots(eventTypeId, startDate, endDate, null);
    }

    public static List<TimeSlot> getAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate, Integer durationMinutes
    ) {
        List<Event_Type__c> eventTypes = [
            SELECT Id, Duration_Minutes__c, Multiple_Durations__c, Min_Booking_Notice_Minutes__c,
                   Buffer_Before_Minutes__c, Buffer_After_Minutes__c,
                   Slot_Interval_Minutes__c, Booking_Window_Days__c,
                   Owner_User__c, OwnerId, Schedule__c, Scheduling_Type__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventTypes.isEmpty()) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found');
        }
        Event_Type__c eventType = eventTypes[0];
        String schedulingType = String.isBlank(eventType.Scheduling_Type__c)
            ? 'Individual' : eventType.Scheduling_Type__c;

        if (schedulingType == 'Collective') {
            return SeatedBookingService.enrichSlotsWithSeatAvailability(
                eventTypeId,
                TeamSchedulingService.getCollectiveAvailableSlots(eventTypeId, startDate, endDate, durationMinutes)
            );
        }
        if (schedulingType == 'Round_Robin') {
            return SeatedBookingService.enrichSlotsWithSeatAvailability(
                eventTypeId,
                TeamSchedulingService.getRoundRobinAvailableSlots(eventTypeId, startDate, endDate, durationMinutes)
            );
        }

        List<Id> hosts = TeamSchedulingService.resolveHostsForAvailability(eventType);
        if (hosts.isEmpty()) {
            return new List<TimeSlot>();
        }
        return SeatedBookingService.enrichSlotsWithSeatAvailability(
            eventTypeId,
            getAvailableSlotsForHost(eventTypeId, hosts[0], startDate, endDate, durationMinutes)
        );
    }

    public static List<TimeSlot> getAvailableSlotsForHost(
        Id eventTypeId, Id hostUserId, Date startDate, Date endDate
    ) {
        return getAvailableSlotsForHost(eventTypeId, hostUserId, startDate, endDate, null);
    }

    public static List<TimeSlot> getAvailableSlotsForHost(
        Id eventTypeId, Id hostUserId, Date startDate, Date endDate, Integer durationMinutes
    ) {
        List<Event_Type__c> eventTypes = [
            SELECT Id, Duration_Minutes__c, Multiple_Durations__c, Min_Booking_Notice_Minutes__c,
                   Buffer_Before_Minutes__c, Buffer_After_Minutes__c,
                   Slot_Interval_Minutes__c, Booking_Window_Days__c,
                   Owner_User__c, OwnerId, Schedule__c, Seats_Per_Slot__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventTypes.isEmpty()) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found');
        }
        Event_Type__c eventType = eventTypes[0];

        Schedule__c schedule;
        if (eventType.Schedule__c != null) {
            List<Schedule__c> schedules = [
                SELECT Id, Time_Zone__c FROM Schedule__c
                WHERE Id = :eventType.Schedule__c WITH USER_MODE LIMIT 1
            ];
            schedule = schedules.isEmpty() ? null : schedules[0];
        }
        if (schedule == null) {
            schedule = getDefaultSchedule(hostUserId);
            if (schedule == null) {
                return new List<TimeSlot>();
            }
        }

        String scheduleTimeZone = String.isNotBlank(schedule.Time_Zone__c)
            ? schedule.Time_Zone__c : UserInfo.getTimeZone().getID();

        List<Travel_Schedule__c> travelSchedules = [
            SELECT Start_Date__c, End_Date__c, Time_Zone__c
            FROM Travel_Schedule__c
            WHERE User__c = :hostUserId
                AND Start_Date__c <= :endDate
                AND End_Date__c >= :startDate
            WITH USER_MODE
        ];

        List<Availability__c> availabilities = [
            SELECT Id, Record_Type__c, Days__c, Start_Time__c, End_Time__c, Override_Date__c
            FROM Availability__c
            WHERE Schedule__c = :schedule.Id
            WITH USER_MODE
            ORDER BY Start_Time__c ASC
        ];

        List<Booking__c> existingBookings = [
            SELECT Id, Start_DateTime__c, End_DateTime__c, Event_Type__c, Event_Type__r.Seats_Per_Slot__c
            FROM Booking__c
            WHERE Host__c = :hostUserId
                AND Status__c IN ('Accepted', 'Pending')
                AND End_DateTime__c >= :Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0))
                AND Start_DateTime__c <= :Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0))
            WITH USER_MODE
            ORDER BY Start_DateTime__c ASC
        ];

        List<CalendarIntegrationService.BusySlot> externalBusy = new List<CalendarIntegrationService.BusySlot>();
        try {
            externalBusy = CalendarIntegrationService.getExternalBusyTimes(
                hostUserId,
                Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
                Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0))
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'External calendar check failed: ' + e.getMessage());
        }

        List<Integer> durations = resolveDurations(eventType);
        List<TimeSlot> slots = new List<TimeSlot>();
        if (durationMinutes != null) {
            slots = calculateSlots(
                eventType, availabilities, existingBookings, externalBusy,
                startDate, endDate, scheduleTimeZone, travelSchedules, durationMinutes
            );
        } else if (durations.size() == 1) {
            slots = calculateSlots(
                eventType, availabilities, existingBookings, externalBusy,
                startDate, endDate, scheduleTimeZone, travelSchedules, durations[0]
            );
        } else {
            Map<String, TimeSlot> slotMap = new Map<String, TimeSlot>();
            for (Integer duration : durations) {
                for (TimeSlot slot : calculateSlots(
                    eventType, availabilities, existingBookings, externalBusy,
                    startDate, endDate, scheduleTimeZone, travelSchedules, duration
                )) {
                    slotMap.put(buildSlotKey(slot.startTime, slot.endTime), slot);
                }
            }
            slots = slotMap.values();
            slots.sort(new TimeSlotComparator());
        }

        List<TimeSlot> availableSlots = new List<TimeSlot>();
        for (TimeSlot slot : slots) {
            if (TeamSchedulingService.isHostAvailableForSlot(hostUserId, slot.startTime, slot.endTime)) {
                availableSlots.add(slot);
            }
        }
        return availableSlots;
    }

    private static String buildSlotKey(Datetime startTime, Datetime endTime) {
        return String.valueOf(startTime.getTime()) + ':' + String.valueOf(endTime.getTime());
    }

    private static String resolveTimeZoneForDate(
        Date targetDate, String defaultTimeZone, List<Travel_Schedule__c> travelSchedules
    ) {
        for (Travel_Schedule__c travel : travelSchedules) {
            if (travel.Start_Date__c <= targetDate && travel.End_Date__c >= targetDate
                && String.isNotBlank(travel.Time_Zone__c)) {
                return travel.Time_Zone__c;
            }
        }
        return defaultTimeZone;
    }

    private static List<TimeSlot> calculateSlots(
        Event_Type__c eventType,
        List<Availability__c> availabilities,
        List<Booking__c> existingBookings,
        List<CalendarIntegrationService.BusySlot> externalBusy,
        Date startDate,
        Date endDate,
        String scheduleTimeZone,
        List<Travel_Schedule__c> travelSchedules,
        Integer durationMinutes
    ) {
        List<TimeSlot> slots = new List<TimeSlot>();
        Integer slotInterval = eventType.Slot_Interval_Minutes__c != null
            ? (Integer)eventType.Slot_Interval_Minutes__c
            : durationMinutes;
        Integer bufferBefore = eventType.Buffer_Before_Minutes__c != null
            ? (Integer)eventType.Buffer_Before_Minutes__c : 0;
        Integer bufferAfter = eventType.Buffer_After_Minutes__c != null
            ? (Integer)eventType.Buffer_After_Minutes__c : 0;
        Integer minNotice = eventType.Min_Booking_Notice_Minutes__c != null
            ? (Integer)eventType.Min_Booking_Notice_Minutes__c : 120;

        Datetime minimumStart = Datetime.now().addMinutes(minNotice);
        Integer bookingWindowDays = eventType.Booking_Window_Days__c != null
            ? (Integer)eventType.Booking_Window_Days__c : 60;
        Date maxBookableDate = Date.today().addDays(bookingWindowDays);
        TimeZone userTz = UserInfo.getTimeZone();

        Date effectiveEnd = endDate < maxBookableDate ? endDate : maxBookableDate;
        Date currentDate = startDate;
        while (currentDate <= effectiveEnd) {
            String dayTimeZone = resolveTimeZoneForDate(currentDate, scheduleTimeZone, travelSchedules);
            TimeZone scheduleTz = TimeZone.getTimeZone(dayTimeZone);
            String dayName = getDayName(currentDate, scheduleTz);
            List<Availability__c> applicableWindows = getApplicableWindows(availabilities, currentDate, dayName);

            for (Availability__c window : applicableWindows) {
                Datetime windowStartLocal = Datetime.newInstance(currentDate, window.Start_Time__c);
                Datetime windowEndLocal = Datetime.newInstance(currentDate, window.End_Time__c);
                Integer tzDeltaMs = userTz.getOffset(windowStartLocal) - scheduleTz.getOffset(windowStartLocal);
                Datetime windowStart = windowStartLocal.addSeconds(tzDeltaMs / 1000);
                Datetime windowEnd = windowEndLocal.addSeconds(tzDeltaMs / 1000);

                Datetime slotStart = windowStart;
                while (slotStart.addMinutes(durationMinutes) <= windowEnd) {
                    Datetime slotEnd = slotStart.addMinutes(durationMinutes);

                    if (slotStart >= minimumStart &&
                        !hasConflict(slotStart, slotEnd, bufferBefore, bufferAfter, existingBookings, eventType) &&
                        !hasExternalConflict(slotStart, slotEnd, externalBusy)) {
                        slots.add(new TimeSlot(slotStart, slotEnd));
                    }

                    slotStart = slotStart.addMinutes(slotInterval);
                }
            }
            currentDate = currentDate.addDays(1);
        }
        return slots;
    }

    private static List<Availability__c> getApplicableWindows(
        List<Availability__c> availabilities, Date targetDate, String dayName
    ) {
        List<Availability__c> dateOverrides = new List<Availability__c>();
        List<Availability__c> workingHours = new List<Availability__c>();

        for (Availability__c av : availabilities) {
            if (av.Record_Type__c == 'Date_Override' && av.Override_Date__c == targetDate) {
                dateOverrides.add(av);
            } else if (av.Record_Type__c == 'Working_Hours' && av.Days__c != null && av.Days__c.contains(dayName)) {
                workingHours.add(av);
            }
        }

        return dateOverrides.isEmpty() ? workingHours : dateOverrides;
    }

    private static Boolean hasExternalConflict(
        Datetime slotStart, Datetime slotEnd,
        List<CalendarIntegrationService.BusySlot> externalBusy
    ) {
        for (CalendarIntegrationService.BusySlot busy : externalBusy) {
            if (slotStart < busy.endTime && slotEnd > busy.startTime) {
                return true;
            }
        }
        return false;
    }

    private static Boolean hasConflict(
        Datetime slotStart, Datetime slotEnd,
        Integer bufferBefore, Integer bufferAfter,
        List<Booking__c> existingBookings,
        Event_Type__c eventType
    ) {
        Datetime bufferedStart = slotStart.addMinutes(-bufferBefore);
        Datetime bufferedEnd = slotEnd.addMinutes(bufferAfter);

        for (Booking__c booking : existingBookings) {
            if (eventType.Seats_Per_Slot__c != null && eventType.Seats_Per_Slot__c > 1
                && booking.Event_Type__c == eventType.Id) {
                continue;
            }
            if (bufferedStart < booking.End_DateTime__c && bufferedEnd > booking.Start_DateTime__c) {
                return true;
            }
        }
        return false;
    }

    private static String getDayName(Date d, TimeZone tz) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        return dt.format('EEEE', tz.getID());
    }

    public class TimeSlot {
        @AuraEnabled public Datetime startTime { get; set; }
        @AuraEnabled public Datetime endTime { get; set; }
        @AuraEnabled public Integer availableSeats { get; set; }

        public TimeSlot(Datetime startTime, Datetime endTime) {
            this.startTime = startTime;
            this.endTime = endTime;
        }
    }

    public class TimeSlotComparator implements Comparator<TimeSlot> {
        public Integer compare(TimeSlot left, TimeSlot right) {
            if (left.startTime == right.startTime) {
                return 0;
            }
            return left.startTime < right.startTime ? -1 : 1;
        }
    }
}
