public with sharing class SchedulingController {

    @AuraEnabled(cacheable=true)
    public static List<Event_Type__c> getActiveEventTypes(Id hostUserId) {
        Id targetUser = hostUserId != null ? hostUserId : UserInfo.getUserId();
        return [
            SELECT Id, Name, Slug__c, Duration_Minutes__c, Description__c,
                   Location__c, Is_Active__c, Owner_User__c, Price__c,
                   Success_Redirect_URL__c
            FROM Event_Type__c
            WHERE (Owner_User__c = :targetUser OR (Owner_User__c = null AND OwnerId = :targetUser))
                AND Is_Active__c = true
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
            AuraHandledException ex = new AuraHandledException('Start date must be before end date');
            ex.setMessage('Start date must be before end date');
            throw ex;
        }
        if (startDate.daysBetween(endDate) > 60) {
            AuraHandledException ex = new AuraHandledException('Date range cannot exceed 60 days');
            ex.setMessage('Date range cannot exceed 60 days');
            throw ex;
        }

        try {
            return AvailabilityService.getAvailableSlots(eventTypeId, startDate, endDate);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c createBooking(
        Id eventTypeId, String startDateTimeStr,
        String bookerEmail, String bookerName, List<String> attendeeEmails
    ) {
        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = parseDateTimeString(startDateTimeStr);
        request.bookerEmail = bookerEmail;
        request.bookerName = bookerName;
        request.attendeeEmails = attendeeEmails;

        try {
            return BookingService.createBooking(request);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c cancelBooking(Id bookingId, String reason) {
        try {
            return BookingService.cancelBooking(bookingId, reason);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c confirmBooking(Id bookingId) {
        try {
            return BookingService.confirmBooking(bookingId);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c rescheduleBooking(Id bookingId, String newStartDateTimeStr) {
        Datetime newStart = parseDateTimeString(newStartDateTimeStr);
        try {
            return BookingService.rescheduleBooking(bookingId, newStart);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
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
                WHERE (Owner_User__c = :UserInfo.getUserId()
                    OR (Owner_User__c = null AND OwnerId = :UserInfo.getUserId()))
                    AND Is_Default__c = true
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
            AuraHandledException ex = new AuraHandledException('Start time must be before end time');
            ex.setMessage('Start time must be before end time');
            throw ex;
        }

        if (recordType == 'Working_Hours' && String.isBlank(days)) {
            AuraHandledException ex = new AuraHandledException('At least one day must be selected for working hours');
            ex.setMessage('At least one day must be selected for working hours');
            throw ex;
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

    @AuraEnabled
    public static Map<String, Boolean> getOnboardingStatus() {
        Id userId = UserInfo.getUserId();
        Map<String, Boolean> status = new Map<String, Boolean>();
        status.put('hasSchedule', ![SELECT Id FROM Schedule__c WHERE Owner_User__c = :userId OR (Owner_User__c = null AND OwnerId = :userId) LIMIT 1].isEmpty());
        status.put('hasAvailability', ![SELECT Id FROM Availability__c WHERE Schedule__r.Owner_User__c = :userId OR (Schedule__r.Owner_User__c = null AND Schedule__r.OwnerId = :userId) LIMIT 1].isEmpty());
        status.put('hasEventType', ![SELECT Id FROM Event_Type__c WHERE (Owner_User__c = :userId OR (Owner_User__c = null AND OwnerId = :userId)) AND Is_Active__c = true LIMIT 1].isEmpty());
        status.put('hasCalendarConnection', ![SELECT Id FROM Calendar_Connection__c WHERE Owner_User__c = :userId LIMIT 1].isEmpty());
        return status;
    }

    @AuraEnabled
    public static Event_Type__c createEventType(String name, Integer durationMinutes, String description) {
        String slug = name.toLowerCase().replaceAll('[^a-z0-9]+', '-').replaceAll('-+$', '') + '-' + String.valueOf(Datetime.now().getTime());

        Event_Type__c et = new Event_Type__c(
            Name = name,
            Slug__c = slug,
            Owner_User__c = UserInfo.getUserId(),
            Duration_Minutes__c = durationMinutes,
            Description__c = description,
            Min_Booking_Notice_Minutes__c = 60,
            Buffer_Before_Minutes__c = 5,
            Buffer_After_Minutes__c = 5,
            Is_Active__c = true,
            Requires_Confirmation__c = false
        );
        insert as user et;
        return et;
    }

    @AuraEnabled
    public static Payment__c createPaymentIntent(Id bookingId) {
        try {
            return PaymentService.createPaymentIntent(bookingId);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c completePayment(Id bookingId) {
        try {
            return BookingService.completePayment(bookingId);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static void scheduleBackgroundJobs() {
        SchedulingJobService.scheduleAllJobs();
    }

    @AuraEnabled(cacheable=true)
    public static List<Routing_Form__c> getActiveRoutingForms(Id hostUserId) {
        return RoutingFormService.getActiveForms(hostUserId);
    }

    @AuraEnabled(cacheable=true)
    public static List<RoutingFormService.FormFieldInfo> getRoutingFormFields(Id routingFormId) {
        return RoutingFormService.getFormFieldInfo(routingFormId);
    }

    @AuraEnabled
    public static RoutingFormService.RoutingResult evaluateRoutingForm(
        Id routingFormId, Map<String, String> fieldResponses
    ) {
        Map<Id, String> responses = new Map<Id, String>();
        if (fieldResponses != null) {
            for (String fieldId : fieldResponses.keySet()) {
                responses.put((Id) fieldId, fieldResponses.get(fieldId));
            }
        }

        try {
            return RoutingFormService.evaluateForm(routingFormId, responses);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static List<Booking__c> createRecurringSeries(
        Id eventTypeId, String firstStartDateTimeStr, String bookerEmail, String bookerName,
        String frequency, Integer occurrences, String seriesEndDateStr
    ) {
        RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
        request.eventTypeId = eventTypeId;
        request.firstStartDateTime = parseDateTimeString(firstStartDateTimeStr);
        request.bookerEmail = bookerEmail;
        request.bookerName = bookerName;
        request.frequency = frequency;
        request.occurrences = occurrences;
        request.seriesEndDate = String.isNotBlank(seriesEndDateStr) ? Date.valueOf(seriesEndDateStr) : null;

        try {
            return RecurringBookingService.createRecurringSeries(request);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static void cancelRecurringSeries(Id recurringPatternId, String reason, Boolean futureOnly) {
        try {
            RecurringBookingService.cancelRecurringSeries(
                recurringPatternId, reason, futureOnly != null ? futureOnly : false
            );
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBookingFormFields() {
        List<Map<String, String>> fields = new List<Map<String, String>>();
        Schema.FieldSet fs = Schema.SObjectType.Booking__c.fieldSets.getMap().get('Booking_Form');
        if (fs == null) {
            return fields;
        }
        for (Schema.FieldSetMember member : fs.getFields()) {
            Map<String, String> fieldInfo = new Map<String, String>();
            fieldInfo.put('apiName', member.getFieldPath());
            fieldInfo.put('label', member.getLabel());
            fieldInfo.put('type', String.valueOf(member.getType()));
            fieldInfo.put('required', String.valueOf(member.getDbRequired() || member.getRequired()));
            fields.add(fieldInfo);
        }
        return fields;
    }

    @AuraEnabled
    public static Booking__c createBookingWithFields(
        Id eventTypeId, String startDateTimeStr, Map<String, Object> fieldValues
    ) {
        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = Datetime.valueOf(startDateTimeStr.replace('T', ' ').replace('Z', ''));
        request.bookerEmail = (String) fieldValues.get('Booker_Email__c');
        request.bookerName = (String) fieldValues.get('Booker_Name__c');
        request.attendeeEmails = new List<String>();

        try {
            Booking__c booking = BookingService.createBooking(request);

            Boolean needsUpdate = false;
            if (fieldValues.containsKey('Booker_Contact__c') && fieldValues.get('Booker_Contact__c') != null) {
                booking.Booker_Contact__c = (Id) fieldValues.get('Booker_Contact__c');
                needsUpdate = true;
            }
            if (fieldValues.containsKey('Location__c') && fieldValues.get('Location__c') != null) {
                booking.Location__c = (String) fieldValues.get('Location__c');
                needsUpdate = true;
            }

            if (needsUpdate) {
                update as user booking;
            }

            return booking;
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    private static Time parseTime(String timeStr) {
        List<String> parts = timeStr.split(':');
        Integer hours = Integer.valueOf(parts[0]);
        Integer minutes = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        return Time.newInstance(hours, minutes, 0, 0);
    }

    private static Datetime parseDateTimeString(String dtStr) {
        String cleaned = dtStr.replace('T', ' ');
        if (cleaned.endsWith('Z')) {
            cleaned = cleaned.removeEnd('Z');
            return Datetime.valueOfGmt(cleaned);
        }
        return Datetime.valueOf(cleaned);
    }
}
