@RestResource(urlMapping='/scheduling/v1/*')
global with sharing class BookingRestApi {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String path = req.requestURI.substringAfter('/scheduling/v1/');

        try {
            if (path.startsWith('event-types')) {
                handleGetEventTypes(req, res);
            } else if (path.startsWith('slots')) {
                handleGetSlots(req, res);
            } else if (path.startsWith('routing-forms/') && path.endsWith('/fields')) {
                String formId = path.substringBetween('routing-forms/', '/fields');
                handleGetRoutingFormFields(formId, res);
            } else if (path.startsWith('routing-forms')) {
                handleGetRoutingForms(req, res);
            } else if (path.startsWith('bookings/')) {
                handleGetBooking(path.substringAfter('bookings/'), res);
            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Endpoint not found')));
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INTERNAL_ERROR', e.getMessage())));
        }
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String path = req.requestURI.substringAfter('/scheduling/v1/');

        try {
            if (path.startsWith('routing-forms/') && path.endsWith('/evaluate')) {
                String formId = path.substringBetween('routing-forms/', '/evaluate');
                handleEvaluateRoutingForm(formId, req, res);
            } else if (path.startsWith('bookings/') && path.endsWith('/cancel')) {
                String bookingUid = path.substringBetween('bookings/', '/cancel');
                handleCancelBooking(bookingUid, req, res);
            } else if (path.startsWith('bookings/') && path.endsWith('/confirm')) {
                String bookingUid = path.substringBetween('bookings/', '/confirm');
                handleConfirmBooking(bookingUid, res);
            } else if (path.startsWith('bookings/') && path.endsWith('/payment-intent')) {
                String bookingUid = path.substringBetween('bookings/', '/payment-intent');
                handleCreatePaymentIntent(bookingUid, res);
            } else if (path.startsWith('bookings/') && path.endsWith('/complete-payment')) {
                String bookingUid = path.substringBetween('bookings/', '/complete-payment');
                handleCompletePayment(bookingUid, res);
            } else if (path == 'bookings/recurring') {
                handleCreateRecurringSeries(req, res);
            } else if (path == 'bookings') {
                handleCreateBooking(req, res);
            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Endpoint not found')));
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INTERNAL_ERROR', e.getMessage())));
        }
    }

    @HttpPatch
    global static void doPatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String path = req.requestURI.substringAfter('/scheduling/v1/');

        try {
            if (path.startsWith('bookings/') && path.endsWith('/reschedule')) {
                String bookingUid = path.substringBetween('bookings/', '/reschedule');
                handleRescheduleBooking(bookingUid, req, res);
            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Endpoint not found')));
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INTERNAL_ERROR', e.getMessage())));
        }
    }

    private static void handleGetRoutingForms(RestRequest req, RestResponse res) {
        String hostUserId = req.params.get('hostUserId');
        if (String.isBlank(hostUserId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INVALID_INPUT', 'hostUserId parameter is required')));
            return;
        }

        List<Routing_Form__c> forms = RoutingFormService.getActiveForms((Id) hostUserId);
        List<RoutingFormResponse> responses = new List<RoutingFormResponse>();
        for (Routing_Form__c form : forms) {
            responses.add(new RoutingFormResponse(form));
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(responses)));
    }

    private static void handleGetRoutingFormFields(String formId, RestResponse res) {
        if (String.isBlank(formId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INVALID_INPUT', 'Routing form ID is required')));
            return;
        }

        List<RoutingFormFieldResponse> fields = new List<RoutingFormFieldResponse>();
        for (RoutingFormService.FormFieldInfo field : RoutingFormService.getFormFieldInfo((Id) formId)) {
            fields.add(new RoutingFormFieldResponse(field));
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(fields)));
    }

    private static void handleEvaluateRoutingForm(String formId, RestRequest req, RestResponse res) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        Map<String, String> responses = new Map<String, String>();
        Map<String, Object> rawResponses = (Map<String, Object>) body.get('fieldResponses');
        if (rawResponses != null) {
            for (String key : rawResponses.keySet()) {
                responses.put(key, String.valueOf(rawResponses.get(key)));
            }
        }

        try {
            Map<Id, String> typedResponses = new Map<Id, String>();
            for (String fieldId : responses.keySet()) {
                typedResponses.put((Id) fieldId, responses.get(fieldId));
            }
            RoutingFormService.RoutingResult result = RoutingFormService.evaluateForm((Id) formId, typedResponses);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new RoutingEvaluationResponse(result))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleConfirmBooking(String bookingUid, RestResponse res) {
        Booking__c booking = findBookingByUid(bookingUid, res);
        if (booking == null) {
            return;
        }

        try {
            Booking__c confirmed = BookingService.confirmBooking(booking.Id);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(confirmed))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleCreatePaymentIntent(String bookingUid, RestResponse res) {
        Booking__c booking = findBookingByUid(bookingUid, res);
        if (booking == null) {
            return;
        }

        try {
            Payment__c payment = PaymentService.createPaymentIntent(booking.Id);
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new PaymentResponse(payment))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleCompletePayment(String bookingUid, RestResponse res) {
        Booking__c booking = findBookingByUid(bookingUid, res);
        if (booking == null) {
            return;
        }

        try {
            Booking__c confirmed = BookingService.completePayment(booking.Id);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(confirmed))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleCreateRecurringSeries(RestRequest req, RestResponse res) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
        request.eventTypeId = (Id) body.get('eventTypeId');
        request.firstStartDateTime = Datetime.valueOf(
            ((String) body.get('firstStartDateTime')).replace('T', ' ').replace('Z', '')
        );
        request.bookerEmail = (String) body.get('bookerEmail');
        request.bookerName = (String) body.get('bookerName');
        request.frequency = (String) body.get('frequency');
        if (body.containsKey('occurrences') && body.get('occurrences') != null) {
            request.occurrences = Integer.valueOf(String.valueOf(body.get('occurrences')));
        }
        if (body.containsKey('seriesEndDate') && body.get('seriesEndDate') != null) {
            request.seriesEndDate = Date.valueOf((String) body.get('seriesEndDate'));
        }

        try {
            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            List<BookingResponse> responses = new List<BookingResponse>();
            for (Booking__c booking : bookings) {
                responses.add(new BookingResponse(booking));
            }
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(responses)));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static Booking__c findBookingByUid(String bookingUid, RestResponse res) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Location__c, Booker_Email__c, Booker_Name__c
            FROM Booking__c
            WHERE UID__c = :bookingUid
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Booking not found')));
            return null;
        }
        return bookings[0];
    }

    private static void handleGetEventTypes(RestRequest req, RestResponse res) {
        String hostUserId = req.params.get('hostUserId');
        if (String.isBlank(hostUserId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('INVALID_INPUT', 'hostUserId parameter is required')));
            return;
        }

        List<Event_Type__c> eventTypes = [
            SELECT Id, Name, Slug__c, Duration_Minutes__c, Description__c, Location__c
            FROM Event_Type__c
            WHERE (Owner_User__c = :hostUserId OR (Owner_User__c = null AND OwnerId = :hostUserId))
                AND Is_Active__c = true
            WITH USER_MODE
            ORDER BY Name ASC
        ];

        List<EventTypeResponse> responses = new List<EventTypeResponse>();
        for (Event_Type__c et : eventTypes) {
            responses.add(new EventTypeResponse(et));
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(responses)));
    }

    private static void handleGetSlots(RestRequest req, RestResponse res) {
        String eventTypeId = req.params.get('eventTypeId');
        String startDateStr = req.params.get('startDate');
        String endDateStr = req.params.get('endDate');

        if (String.isBlank(eventTypeId) || String.isBlank(startDateStr) || String.isBlank(endDateStr)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiError('INVALID_INPUT', 'eventTypeId, startDate, and endDate parameters are required')
            ));
            return;
        }

        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);

        if (startDate.daysBetween(endDate) > 60) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiError('INVALID_INPUT', 'Date range cannot exceed 60 days')
            ));
            return;
        }

        String durationParam = req.params.get('durationMinutes');
        Integer durationMinutes = String.isNotBlank(durationParam)
            ? Integer.valueOf(durationParam) : null;

        List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
            eventTypeId, startDate, endDate, durationMinutes
        );

        List<SlotResponse> slotResponses = new List<SlotResponse>();
        for (AvailabilityService.TimeSlot slot : slots) {
            slotResponses.add(new SlotResponse(slot));
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(slotResponses)));
    }

    private static void handleGetBooking(String bookingUid, RestResponse res) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Location__c, Booker_Email__c, Booker_Name__c,
                   Event_Type__r.Name, Event_Type__r.Duration_Minutes__c
            FROM Booking__c
            WHERE UID__c = :bookingUid
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookings.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Booking not found')));
            return;
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(bookings[0]))));
    }

    private static void handleCreateBooking(RestRequest req, RestResponse res) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        String eventTypeId = (String) body.get('eventTypeId');
        String startDateTime = (String) body.get('startDateTime');
        String bookerEmail = (String) body.get('bookerEmail');
        String bookerName = (String) body.get('bookerName');
        List<Object> attendeeList = (List<Object>) body.get('attendeeEmails');

        List<String> attendeeEmails = new List<String>();
        if (attendeeList != null) {
            for (Object email : attendeeList) {
                attendeeEmails.add((String) email);
            }
        }

        BookingService.BookingRequest request = new BookingService.BookingRequest();
        request.eventTypeId = eventTypeId;
        request.startDateTime = Datetime.valueOf(startDateTime.replace('T', ' ').replace('Z', ''));
        request.bookerEmail = bookerEmail;
        request.bookerName = bookerName;
        request.attendeeEmails = attendeeEmails;

        try {
            Booking__c booking = BookingService.createBooking(request);
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(booking))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleCancelBooking(String bookingUid, RestRequest req, RestResponse res) {
        List<Booking__c> bookings = [
            SELECT Id FROM Booking__c WHERE UID__c = :bookingUid WITH USER_MODE LIMIT 1
        ];

        if (bookings.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Booking not found')));
            return;
        }

        String reason;
        if (req.requestBody != null) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            reason = (String) body.get('reason');
        }

        try {
            Booking__c cancelled = BookingService.cancelBooking(bookings[0].Id, reason);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(cancelled))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    private static void handleRescheduleBooking(String bookingUid, RestRequest req, RestResponse res) {
        List<Booking__c> bookings = [
            SELECT Id FROM Booking__c WHERE UID__c = :bookingUid WITH USER_MODE LIMIT 1
        ];

        if (bookings.isEmpty()) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError('NOT_FOUND', 'Booking not found')));
            return;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        String newStartDateTime = (String) body.get('startDateTime');

        Datetime newStart = Datetime.valueOf(newStartDateTime.replace('T', ' ').replace('Z', ''));

        try {
            Booking__c rescheduled = BookingService.rescheduleBooking(bookings[0].Id, newStart);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponse(new BookingResponse(rescheduled))));
        } catch (SchedulingException e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiError(e.getErrorCode(), e.getMessage())));
        }
    }

    global class ApiResponse {
        public Object data;
        public ApiResponse(Object data) { this.data = data; }
    }

    global class ApiError {
        public String errorCode;
        public String message;
        public ApiError(String errorCode, String message) {
            this.errorCode = errorCode;
            this.message = message;
        }
    }

    global class EventTypeResponse {
        public String id;
        public String name;
        public String slug;
        public Decimal durationMinutes;
        public String description;
        public String location;

        public EventTypeResponse(Event_Type__c et) {
            this.id = et.Id;
            this.name = et.Name;
            this.slug = et.Slug__c;
            this.durationMinutes = et.Duration_Minutes__c;
            this.description = et.Description__c;
            this.location = et.Location__c;
        }
    }

    global class SlotResponse {
        public String startTime;
        public String endTime;
        public Integer availableSeats;

        public SlotResponse(AvailabilityService.TimeSlot slot) {
            this.startTime = slot.startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            this.endTime = slot.endTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            this.availableSeats = slot.availableSeats;
        }
    }

    global class RoutingFormResponse {
        public String id;
        public String name;
        public String description;

        public RoutingFormResponse(Routing_Form__c form) {
            this.id = form.Id;
            this.name = form.Name;
            this.description = form.Description__c;
        }
    }

    global class RoutingFormFieldResponse {
        public String id;
        public String name;
        public String fieldType;
        public List<String> options;

        public RoutingFormFieldResponse(RoutingFormService.FormFieldInfo field) {
            this.id = field.id;
            this.name = field.name;
            this.fieldType = field.fieldType;
            this.options = field.options;
        }
    }

    global class RoutingEvaluationResponse {
        public String eventTypeId;
        public String eventTypeName;

        public RoutingEvaluationResponse(RoutingFormService.RoutingResult result) {
            this.eventTypeId = result.eventTypeId;
            this.eventTypeName = result.eventTypeName;
        }
    }

    global class PaymentResponse {
        public String id;
        public String status;
        public Decimal amount;
        public String externalPaymentId;

        public PaymentResponse(Payment__c payment) {
            this.id = payment.Id;
            this.status = payment.Status__c;
            this.amount = payment.Amount__c;
            this.externalPaymentId = payment.External_Payment_Id__c;
        }
    }

    global class BookingResponse {
        public String id;
        public String uid;
        public String title;
        public String startDateTime;
        public String endDateTime;
        public String status;
        public String location;
        public String bookerEmail;
        public String bookerName;

        public BookingResponse(Booking__c b) {
            this.id = b.Id;
            this.uid = b.UID__c;
            this.title = b.Title__c;
            this.startDateTime = b.Start_DateTime__c != null ? b.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : null;
            this.endDateTime = b.End_DateTime__c != null ? b.End_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : null;
            this.status = b.Status__c;
            this.location = b.Location__c;
            this.bookerEmail = b.Booker_Email__c;
            this.bookerName = b.Booker_Name__c;
        }
    }
}
