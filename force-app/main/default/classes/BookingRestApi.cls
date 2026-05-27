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
            if (path.startsWith('bookings/') && path.endsWith('/cancel')) {
                String bookingUid = path.substringBetween('bookings/', '/cancel');
                handleCancelBooking(bookingUid, req, res);
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

        List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(eventTypeId, startDate, endDate);

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

        public SlotResponse(AvailabilityService.TimeSlot slot) {
            this.startTime = slot.startTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            this.endTime = slot.endTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
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
