public with sharing class SchedulingController {

    @AuraEnabled(cacheable=true)
    public static List<Event_Type__c> getActiveEventTypes(Id hostUserId) {
        Id targetUser = hostUserId != null ? hostUserId : UserInfo.getUserId();
        return [
            SELECT Id, Name, Slug__c, Duration_Minutes__c, Multiple_Durations__c, Description__c,
                   Location__c, Video_Provider__c, Is_Active__c, Owner_User__c, Price__c,
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
        Id eventTypeId, String startDateStr, String endDateStr, Integer durationMinutes
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
            return AvailabilityService.getAvailableSlots(eventTypeId, startDate, endDate, durationMinutes);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Integer> getEventTypeDurations(Id eventTypeId) {
        List<Event_Type__c> eventTypes = [
            SELECT Duration_Minutes__c, Multiple_Durations__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];
        if (eventTypes.isEmpty()) {
            return new List<Integer>();
        }
        return AvailabilityService.resolveDurations(eventTypes[0]);
    }

    @AuraEnabled(cacheable=true)
    public static List<Travel_Schedule__c> getMyTravelSchedules() {
        return [
            SELECT Id, Name, Start_Date__c, End_Date__c, Time_Zone__c
            FROM Travel_Schedule__c
            WHERE User__c = :UserInfo.getUserId()
            WITH USER_MODE
            ORDER BY Start_Date__c DESC
        ];
    }

    @AuraEnabled
    public static Travel_Schedule__c createTravelSchedule(
        String startDateStr, String endDateStr, String timeZone
    ) {
        Travel_Schedule__c travel = new Travel_Schedule__c(
            User__c = UserInfo.getUserId(),
            Start_Date__c = Date.valueOf(startDateStr),
            End_Date__c = Date.valueOf(endDateStr),
            Time_Zone__c = timeZone
        );
        insert as user travel;
        return travel;
    }

    @AuraEnabled(cacheable=true)
    public static List<BookingFieldService.FieldInfo> getBookingFieldsForEventType(Id eventTypeId) {
        return BookingFieldService.getFieldsForEventType(eventTypeId);
    }

    @AuraEnabled
    public static PaymentService.PaymentCheckoutInfo getPaymentCheckoutInfo(Id bookingId) {
        try {
            return PaymentService.getCheckoutInfo(bookingId);
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled(cacheable=true)
    public static MeetingOptionsService.BookingLocationSettings getBookingLocationSettings(
        Id hostUserId, Id eventTypeId
    ) {
        return MeetingOptionsService.getBookingLocationSettings(hostUserId, eventTypeId);
    }

    @AuraEnabled
    public static Booking__c createBookingWithCustomFields(
        Id eventTypeId, String startDateTimeStr, String bookerEmail, String bookerName,
        String bookerPhone, Map<String, String> customFieldResponses,
        String location, String videoProvider
    ) {
        Map<Id, String> responses = new Map<Id, String>();
        if (customFieldResponses != null) {
            for (String fieldId : customFieldResponses.keySet()) {
                responses.put((Id) fieldId, customFieldResponses.get(fieldId));
            }
        }

        try {
            BookingFieldService.validateRequiredFields(eventTypeId, responses);

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventTypeId;
            request.startDateTime = parseDateTimeString(startDateTimeStr);
            request.bookerEmail = bookerEmail;
            request.bookerName = bookerName;
            request.attendeeEmails = new List<String>();
            request.location = location;
            request.videoProvider = videoProvider;

            Booking__c booking = BookingService.createBooking(request);
            if (String.isNotBlank(bookerPhone)) {
                booking.Booker_Phone__c = bookerPhone;
                update as user booking;
            }
            BookingFieldService.saveResponses(booking.Id, responses);
            return booking;
        } catch (SchedulingException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static Booking__c createBooking(
        Id eventTypeId, String startDateTimeStr,
        String bookerEmail, String bookerName, List<String> attendeeEmails,
        String location, String videoProvider
    ) {
        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = parseDateTimeString(startDateTimeStr);
        request.bookerEmail = bookerEmail;
        request.bookerName = bookerName;
        request.attendeeEmails = attendeeEmails;
        request.location = location;
        request.videoProvider = videoProvider;

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
    public static List<Booking__c> getMyBookings(String startDateStr, String endDateStr, String searchTerm) {
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        return BookingService.getBookingsForHost(UserInfo.getUserId(), startDate, endDate, searchTerm);
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
        Id eventTypeId, String startDateTimeStr, Map<String, Object> fieldValues,
        String location, String videoProvider
    ) {
        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = Datetime.valueOf(startDateTimeStr.replace('T', ' ').replace('Z', ''));
        request.bookerEmail = (String) fieldValues.get('Booker_Email__c');
        request.bookerName = (String) fieldValues.get('Booker_Name__c');
        request.attendeeEmails = new List<String>();
        request.location = String.isNotBlank(location)
            ? location
            : (String) fieldValues.get('Location__c');
        request.videoProvider = videoProvider;

        try {
            Booking__c booking = BookingService.createBooking(request);

            Boolean needsUpdate = false;
            if (fieldValues.containsKey('Booker_Contact__c') && fieldValues.get('Booker_Contact__c') != null) {
                booking.Booker_Contact__c = (Id) fieldValues.get('Booker_Contact__c');
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

    public class RoutingFormDetail {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public List<RoutingFieldDetail> fields { get; set; }
        @AuraEnabled public List<RoutingRouteDetail> routes { get; set; }
    }

    public class RoutingFieldDetail {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public String options { get; set; }
    }

    public class RoutingRouteDetail {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id targetEventTypeId { get; set; }
        @AuraEnabled public String targetEventTypeName { get; set; }
        @AuraEnabled public String conditionFieldId { get; set; }
        @AuraEnabled public String conditionOperator { get; set; }
        @AuraEnabled public String conditionValue { get; set; }
    }

    public class WorkflowDetail {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String triggerEvent { get; set; }
        @AuraEnabled public Id eventTypeId { get; set; }
        @AuraEnabled public String eventTypeName { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public Decimal timeOffsetMinutes { get; set; }
        @AuraEnabled public List<WorkflowStepDetail> steps { get; set; }
    }

    public class WorkflowStepDetail {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String actionType { get; set; }
        @AuraEnabled public String recipient { get; set; }
        @AuraEnabled public String template { get; set; }
        @AuraEnabled public String webhookUrl { get; set; }
        @AuraEnabled public Decimal sortOrder { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static RoutingFormDetail getRoutingFormDetail(Id routingFormId) {
        assertRoutingFormOwnership(routingFormId);

        Routing_Form__c form = [
            SELECT Id, Name, Description__c,
                (SELECT Id, Name, Field_Type__c, Options__c FROM Fields__r ORDER BY Name ASC),
                (SELECT Id, Condition__c, Target_Event_Type__c, Target_Event_Type__r.Name FROM Routes__r ORDER BY CreatedDate ASC)
            FROM Routing_Form__c
            WHERE Id = :routingFormId
            WITH USER_MODE
            LIMIT 1
        ];

        RoutingFormDetail detail = new RoutingFormDetail();
        detail.id = form.Id;
        detail.name = form.Name;
        detail.description = form.Description__c;
        detail.fields = new List<RoutingFieldDetail>();
        detail.routes = new List<RoutingRouteDetail>();

        for (Routing_Form_Field__c field : form.Fields__r) {
            RoutingFieldDetail fieldDetail = new RoutingFieldDetail();
            fieldDetail.id = field.Id;
            fieldDetail.name = field.Name;
            fieldDetail.fieldType = field.Field_Type__c;
            fieldDetail.options = field.Options__c;
            detail.fields.add(fieldDetail);
        }

        for (Routing_Form_Route__c route : form.Routes__r) {
            RoutingRouteDetail routeDetail = new RoutingRouteDetail();
            routeDetail.id = route.Id;
            routeDetail.targetEventTypeId = route.Target_Event_Type__c;
            routeDetail.targetEventTypeName = route.Target_Event_Type__r != null ? route.Target_Event_Type__r.Name : null;
            parseRouteCondition(route.Condition__c, routeDetail);
            detail.routes.add(routeDetail);
        }

        return detail;
    }

    @AuraEnabled
    public static Routing_Form__c saveRoutingForm(Id formId, String name, String description) {
        if (String.isBlank(name)) {
            throw handledException('Form name is required');
        }

        Routing_Form__c form;
        if (formId != null) {
            assertRoutingFormOwnership(formId);
            form = [
                SELECT Id, Name, Description__c
                FROM Routing_Form__c
                WHERE Id = :formId
                WITH USER_MODE
                LIMIT 1
            ];
            form.Name = name;
            form.Description__c = description;
            update form;
        } else {
            form = new Routing_Form__c(
                Name = name,
                Description__c = description,
                Owner_User__c = UserInfo.getUserId()
            );
            insert form;
        }
        return form;
    }

    @AuraEnabled
    public static Routing_Form_Field__c saveRoutingField(
        Id fieldId, Id formId, String name, String fieldType, String options
    ) {
        if (formId == null || String.isBlank(name) || String.isBlank(fieldType)) {
            throw handledException('Form, name, and field type are required');
        }
        assertRoutingFormOwnership(formId);

        Routing_Form_Field__c field;
        if (fieldId != null) {
            List<Routing_Form_Field__c> existingFields = [
                SELECT Id, Routing_Form__c, Name, Field_Type__c, Options__c
                FROM Routing_Form_Field__c
                WHERE Id = :fieldId AND Routing_Form__c = :formId
                WITH USER_MODE
                LIMIT 1
            ];
            if (existingFields.isEmpty()) {
                throw handledException('Routing form field not found');
            }
            field = existingFields[0];
            field.Name = name;
            field.Field_Type__c = fieldType;
            field.Options__c = options;
            update field;
        } else {
            field = new Routing_Form_Field__c(
                Routing_Form__c = formId,
                Name = name,
                Field_Type__c = fieldType,
                Options__c = options
            );
            insert field;
        }
        return field;
    }

    @AuraEnabled
    public static Routing_Form_Route__c saveRoutingRoute(
        Id routeId, Id formId, Id targetEventTypeId,
        String conditionFieldId, String conditionOperator, String conditionValue
    ) {
        if (formId == null || targetEventTypeId == null) {
            throw handledException('Form and target event type are required');
        }
        assertRoutingFormOwnership(formId);

        Map<String, String> condition = new Map<String, String>();
        if (String.isNotBlank(conditionFieldId)) {
            condition.put('fieldId', conditionFieldId);
            condition.put('operator', String.isNotBlank(conditionOperator) ? conditionOperator : 'equals');
            condition.put('value', conditionValue != null ? conditionValue : '');
        }

        Routing_Form_Route__c route;
        if (routeId != null) {
            List<Routing_Form_Route__c> existingRoutes = [
                SELECT Id, Routing_Form__c, Target_Event_Type__c, Condition__c
                FROM Routing_Form_Route__c
                WHERE Id = :routeId AND Routing_Form__c = :formId
                WITH USER_MODE
                LIMIT 1
            ];
            if (existingRoutes.isEmpty()) {
                throw handledException('Routing form route not found');
            }
            route = existingRoutes[0];
            route.Target_Event_Type__c = targetEventTypeId;
            route.Condition__c = condition.isEmpty() ? null : JSON.serialize(condition);
            update route;
        } else {
            route = new Routing_Form_Route__c(
                Routing_Form__c = formId,
                Target_Event_Type__c = targetEventTypeId,
                Condition__c = condition.isEmpty() ? null : JSON.serialize(condition)
            );
            insert route;
        }
        return route;
    }

    @AuraEnabled
    public static void deleteRoutingField(Id fieldId) {
        if (fieldId == null) {
            throw handledException('Field id is required');
        }

        Routing_Form_Field__c field = [
            SELECT Id, Routing_Form__c
            FROM Routing_Form_Field__c
            WHERE Id = :fieldId
            WITH USER_MODE
            LIMIT 1
        ];
        assertRoutingFormOwnership(field.Routing_Form__c);
        delete field;
    }

    @AuraEnabled
    public static void deleteRoutingRoute(Id routeId) {
        if (routeId == null) {
            throw handledException('Route id is required');
        }

        Routing_Form_Route__c route = [
            SELECT Id, Routing_Form__c
            FROM Routing_Form_Route__c
            WHERE Id = :routeId
            WITH USER_MODE
            LIMIT 1
        ];
        assertRoutingFormOwnership(route.Routing_Form__c);
        delete route;
    }

    @AuraEnabled(cacheable=true)
    public static List<Workflow__c> getMyWorkflows() {
        return [
            SELECT Id, Name, Trigger_Event__c, Is_Active__c, Event_Type__c, Event_Type__r.Name, Time_Offset_Minutes__c
            FROM Workflow__c
            WHERE OwnerId = :UserInfo.getUserId()
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static WorkflowDetail getWorkflowDetail(Id workflowId) {
        assertWorkflowOwnership(workflowId);

        Workflow__c workflow = [
            SELECT Id, Name, Trigger_Event__c, Is_Active__c, Event_Type__c, Event_Type__r.Name, Time_Offset_Minutes__c,
                (SELECT Id, Action_Type__c, Recipient__c, Template__c, Webhook_URL__c, Sort_Order__c
                 FROM Steps__r
                 ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC)
            FROM Workflow__c
            WHERE Id = :workflowId
            WITH USER_MODE
            LIMIT 1
        ];

        WorkflowDetail detail = new WorkflowDetail();
        detail.id = workflow.Id;
        detail.name = workflow.Name;
        detail.triggerEvent = workflow.Trigger_Event__c;
        detail.eventTypeId = workflow.Event_Type__c;
        detail.eventTypeName = workflow.Event_Type__r != null ? workflow.Event_Type__r.Name : null;
        detail.isActive = workflow.Is_Active__c;
        detail.timeOffsetMinutes = workflow.Time_Offset_Minutes__c;
        detail.steps = new List<WorkflowStepDetail>();

        for (Workflow_Step__c step : workflow.Steps__r) {
            WorkflowStepDetail stepDetail = new WorkflowStepDetail();
            stepDetail.id = step.Id;
            stepDetail.actionType = step.Action_Type__c;
            stepDetail.recipient = step.Recipient__c;
            stepDetail.template = step.Template__c;
            stepDetail.webhookUrl = step.Webhook_URL__c;
            stepDetail.sortOrder = step.Sort_Order__c;
            detail.steps.add(stepDetail);
        }

        return detail;
    }

    @AuraEnabled
    public static Workflow__c saveWorkflow(
        Id workflowId, String name, String triggerEvent, Id eventTypeId,
        Boolean isActive, Decimal timeOffsetMinutes
    ) {
        if (String.isBlank(name) || String.isBlank(triggerEvent)) {
            throw handledException('Name and trigger event are required');
        }

        Workflow__c workflow;
        if (workflowId != null) {
            assertWorkflowOwnership(workflowId);
            workflow = [
                SELECT Id, Name, Trigger_Event__c, Is_Active__c, Event_Type__c, Time_Offset_Minutes__c
                FROM Workflow__c
                WHERE Id = :workflowId
                WITH USER_MODE
                LIMIT 1
            ];
            workflow.Name = name;
            workflow.Trigger_Event__c = triggerEvent;
            workflow.Event_Type__c = eventTypeId;
            workflow.Is_Active__c = isActive != null ? isActive : false;
            workflow.Time_Offset_Minutes__c = timeOffsetMinutes;
            update workflow;
        } else {
            workflow = new Workflow__c(
                Name = name,
                Trigger_Event__c = triggerEvent,
                Event_Type__c = eventTypeId,
                Is_Active__c = isActive != null ? isActive : true,
                Time_Offset_Minutes__c = timeOffsetMinutes
            );
            insert workflow;
        }
        return workflow;
    }

    @AuraEnabled
    public static Workflow_Step__c saveWorkflowStep(
        Id stepId, Id workflowId, String actionType, String recipient,
        String template, String webhookUrl, Decimal sortOrder
    ) {
        if (workflowId == null || String.isBlank(actionType)) {
            throw handledException('Workflow and action type are required');
        }
        assertWorkflowOwnership(workflowId);

        Workflow_Step__c step;
        if (stepId != null) {
            List<Workflow_Step__c> existingSteps = [
                SELECT Id, Workflow__c, Action_Type__c, Recipient__c, Template__c, Webhook_URL__c, Sort_Order__c
                FROM Workflow_Step__c
                WHERE Id = :stepId AND Workflow__c = :workflowId
                WITH USER_MODE
                LIMIT 1
            ];
            if (existingSteps.isEmpty()) {
                throw handledException('Workflow step not found');
            }
            step = existingSteps[0];
            step.Action_Type__c = actionType;
            step.Recipient__c = recipient;
            step.Template__c = template;
            step.Webhook_URL__c = webhookUrl;
            step.Sort_Order__c = sortOrder;
            update step;
        } else {
            step = new Workflow_Step__c(
                Workflow__c = workflowId,
                Action_Type__c = actionType,
                Recipient__c = recipient,
                Template__c = template,
                Webhook_URL__c = webhookUrl,
                Sort_Order__c = sortOrder
            );
            insert step;
        }
        return step;
    }

    @AuraEnabled
    public static void deleteWorkflowStep(Id stepId) {
        if (stepId == null) {
            throw handledException('Step id is required');
        }

        Workflow_Step__c step = [
            SELECT Id, Workflow__c
            FROM Workflow_Step__c
            WHERE Id = :stepId
            WITH USER_MODE
            LIMIT 1
        ];
        assertWorkflowOwnership(step.Workflow__c);
        delete step;
    }

    private static void assertRoutingFormOwnership(Id formId) {
        List<Routing_Form__c> forms = [
            SELECT Id
            FROM Routing_Form__c
            WHERE Id = :formId
                AND (Owner_User__c = :UserInfo.getUserId()
                    OR (Owner_User__c = null AND OwnerId = :UserInfo.getUserId()))
            WITH USER_MODE
            LIMIT 1
        ];
        if (forms.isEmpty()) {
            throw handledException('Routing form not found or access denied');
        }
    }

    private static void assertWorkflowOwnership(Id workflowId) {
        List<Workflow__c> workflows = [
            SELECT Id
            FROM Workflow__c
            WHERE Id = :workflowId AND OwnerId = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];
        if (workflows.isEmpty()) {
            throw handledException('Workflow not found or access denied');
        }
    }

    private static void parseRouteCondition(String conditionJson, RoutingRouteDetail routeDetail) {
        if (String.isBlank(conditionJson)) {
            return;
        }
        Map<String, Object> condition = (Map<String, Object>) JSON.deserializeUntyped(conditionJson);
        routeDetail.conditionFieldId = (String) condition.get('fieldId');
        routeDetail.conditionOperator = (String) condition.get('operator');
        routeDetail.conditionValue = (String) condition.get('value');
    }

    private static AuraHandledException handledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
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
