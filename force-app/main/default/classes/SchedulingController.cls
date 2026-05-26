public with sharing class SchedulingController {

    @AuraEnabled(cacheable=true)
    public static List<Event_Type__c> getActiveEventTypes(Id hostUserId) {
        Id targetUser = hostUserId != null ? hostUserId : UserInfo.getUserId();
        return [
            SELECT Id, Name, Slug__c, Duration_Minutes__c, Description__c,
                   Location__c, Is_Active__c, Owner_User__c
            FROM Event_Type__c
            WHERE Owner_User__c = :targetUser AND Is_Active__c = true
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AvailabilityService.TimeSlot> getAvailableSlots(
        Id eventTypeId, String startDateStr, String endDateStr
    ) {
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);

        if (startDate > endDate) {
            throw new AuraHandledException('Start date must be before end date');
        }
        if (startDate.daysBetween(endDate) > 60) {
            throw new AuraHandledException('Date range cannot exceed 60 days');
        }

        try {
            return AvailabilityService.getAvailableSlots(eventTypeId, startDate, endDate);
        } catch (SchedulingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Booking__c createBooking(
        Id eventTypeId, String startDateTimeStr,
        String bookerEmail, String bookerName, List<String> attendeeEmails
    ) {
        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = Datetime.valueOf(startDateTimeStr.replace('T', ' ').replace('Z', ''));
        request.bookerEmail = bookerEmail;
        request.bookerName = bookerName;
        request.attendeeEmails = attendeeEmails;

        try {
            return BookingService.createBooking(request);
        } catch (SchedulingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Booking__c cancelBooking(Id bookingId, String reason) {
        try {
            return BookingService.cancelBooking(bookingId, reason);
        } catch (SchedulingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Booking__c confirmBooking(Id bookingId) {
        try {
            return BookingService.confirmBooking(bookingId);
        } catch (SchedulingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Booking__c rescheduleBooking(Id bookingId, String newStartDateTimeStr) {
        Datetime newStart = Datetime.valueOf(newStartDateTimeStr.replace('T', ' ').replace('Z', ''));
        try {
            return BookingService.rescheduleBooking(bookingId, newStart);
        } catch (SchedulingException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Booking__c> getMyBookings(String startDateStr, String endDateStr) {
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        return BookingService.getBookingsForHost(UserInfo.getUserId(), startDate, endDate);
    }

    @AuraEnabled(cacheable=true)
    public static List<Schedule__c> getMySchedules() {
        return AvailabilityService.getSchedulesForUser(UserInfo.getUserId());
    }

    @AuraEnabled
    public static Schedule__c createSchedule(String name, String timeZone, Boolean isDefault) {
        if (isDefault) {
            List<Schedule__c> existing = [
                SELECT Id, Is_Default__c
                FROM Schedule__c
                WHERE Owner_User__c = :UserInfo.getUserId() AND Is_Default__c = true
                WITH USER_MODE
            ];
            for (Schedule__c s : existing) {
                s.Is_Default__c = false;
            }
            if (!existing.isEmpty()) {
                update as user existing;
            }
        }

        Schedule__c schedule = new Schedule__c(
            Name = name,
            Owner_User__c = UserInfo.getUserId(),
            Time_Zone__c = timeZone,
            Is_Default__c = isDefault
        );
        insert as user schedule;
        return schedule;
    }

    @AuraEnabled
    public static Availability__c addAvailability(
        Id scheduleId, String recordType, String days,
        String startTimeStr, String endTimeStr, String overrideDateStr
    ) {
        Time startTime = parseTime(startTimeStr);
        Time endTime = parseTime(endTimeStr);

        if (startTime >= endTime) {
            throw new AuraHandledException('Start time must be before end time');
        }

        Availability__c availability = new Availability__c(
            Schedule__c = scheduleId,
            Record_Type__c = recordType,
            Days__c = days,
            Start_Time__c = startTime,
            End_Time__c = endTime,
            Override_Date__c = String.isNotBlank(overrideDateStr) ? Date.valueOf(overrideDateStr) : null
        );
        insert as user availability;
        return availability;
    }

    private static Time parseTime(String timeStr) {
        List<String> parts = timeStr.split(':');
        Integer hours = Integer.valueOf(parts[0]);
        Integer minutes = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        return Time.newInstance(hours, minutes, 0, 0);
    }
}
