public with sharing class AvailabilityService {

    private static final Map<String, Integer> DAY_INDEX_MAP = new Map<String, Integer>{
        'Sunday' => 0, 'Monday' => 1, 'Tuesday' => 2, 'Wednesday' => 3,
        'Thursday' => 4, 'Friday' => 5, 'Saturday' => 6
    };

    public static List<Schedule__c> getSchedulesForUser(Id userId) {
        return [
            SELECT Id, Name, Time_Zone__c, Is_Default__c, Owner_User__c,
                (SELECT Id, Record_Type__c, Days__c, Start_Time__c, End_Time__c, Override_Date__c
                 FROM Availabilities__r
                 ORDER BY Start_Time__c ASC)
            FROM Schedule__c
            WHERE Owner_User__c = :userId
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
            WHERE Owner_User__c = :userId AND Is_Default__c = true
            WITH USER_MODE
            LIMIT 1
        ];
        if (schedules.isEmpty()) {
            return null;
        }
        return schedules[0];
    }

    public static List<TimeSlot> getAvailableSlots(Id eventTypeId, Date startDate, Date endDate) {
        Event_Type__c eventType = [
            SELECT Id, Duration_Minutes__c, Min_Booking_Notice_Minutes__c,
                   Buffer_Before_Minutes__c, Buffer_After_Minutes__c,
                   Slot_Interval_Minutes__c, Booking_Window_Days__c,
                   Owner_User__c, Schedule__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        if (eventType == null) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found');
        }

        Id scheduleId = eventType.Schedule__c;
        if (scheduleId == null) {
            Schedule__c defaultSchedule = getDefaultSchedule(eventType.Owner_User__c);
            if (defaultSchedule == null) {
                return new List<TimeSlot>();
            }
            scheduleId = defaultSchedule.Id;
        }

        List<Availability__c> availabilities = [
            SELECT Id, Record_Type__c, Days__c, Start_Time__c, End_Time__c, Override_Date__c
            FROM Availability__c
            WHERE Schedule__c = :scheduleId
            WITH USER_MODE
            ORDER BY Start_Time__c ASC
        ];

        List<Booking__c> existingBookings = [
            SELECT Id, Start_DateTime__c, End_DateTime__c
            FROM Booking__c
            WHERE Host__c = :eventType.Owner_User__c
                AND Status__c IN ('Accepted', 'Pending')
                AND End_DateTime__c >= :Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0))
                AND Start_DateTime__c <= :Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0))
            WITH USER_MODE
            ORDER BY Start_DateTime__c ASC
        ];

        List<CalendarIntegrationService.BusySlot> externalBusy = new List<CalendarIntegrationService.BusySlot>();
        try {
            externalBusy = CalendarIntegrationService.getExternalBusyTimes(
                eventType.Owner_User__c,
                Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
                Datetime.newInstance(endDate, Time.newInstance(23, 59, 59, 0))
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'External calendar check failed: ' + e.getMessage());
        }

        return calculateSlots(eventType, availabilities, existingBookings, externalBusy, startDate, endDate);
    }

    private static List<TimeSlot> calculateSlots(
        Event_Type__c eventType,
        List<Availability__c> availabilities,
        List<Booking__c> existingBookings,
        List<CalendarIntegrationService.BusySlot> externalBusy,
        Date startDate,
        Date endDate
    ) {
        List<TimeSlot> slots = new List<TimeSlot>();
        Integer durationMinutes = (Integer)eventType.Duration_Minutes__c;
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

        Date currentDate = startDate;
        while (currentDate <= endDate) {
            String dayName = getDayName(currentDate);
            List<Availability__c> applicableWindows = getApplicableWindows(availabilities, currentDate, dayName);

            for (Availability__c window : applicableWindows) {
                Datetime windowStart = Datetime.newInstance(currentDate, window.Start_Time__c);
                Datetime windowEnd = Datetime.newInstance(currentDate, window.End_Time__c);

                Datetime slotStart = windowStart;
                while (slotStart.addMinutes(durationMinutes) <= windowEnd) {
                    Datetime slotEnd = slotStart.addMinutes(durationMinutes);

                    if (slotStart >= minimumStart &&
                        !hasConflict(slotStart, slotEnd, bufferBefore, bufferAfter, existingBookings) &&
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
        List<Booking__c> existingBookings
    ) {
        Datetime bufferedStart = slotStart.addMinutes(-bufferBefore);
        Datetime bufferedEnd = slotEnd.addMinutes(bufferAfter);

        for (Booking__c booking : existingBookings) {
            if (bufferedStart < booking.End_DateTime__c && bufferedEnd > booking.Start_DateTime__c) {
                return true;
            }
        }
        return false;
    }

    private static String getDayName(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        return dt.format('EEEE');
    }

    public class TimeSlot {
        @AuraEnabled public Datetime startTime { get; set; }
        @AuraEnabled public Datetime endTime { get; set; }

        public TimeSlot(Datetime startTime, Datetime endTime) {
            this.startTime = startTime;
            this.endTime = endTime;
        }
    }
}
