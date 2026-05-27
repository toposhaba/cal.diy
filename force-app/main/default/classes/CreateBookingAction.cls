public with sharing class CreateBookingAction {

    @InvocableMethod(label='Create Booking' description='Creates a new booking for a given event type and time slot' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                BookingService.BookingRequest bookingReq = new BookingService.BookingRequest();
                bookingReq.eventTypeId = req.eventTypeId;
                bookingReq.startDateTime = req.startDateTime;
                bookingReq.bookerEmail = req.bookerEmail;
                bookingReq.bookerName = req.bookerName;
                bookingReq.attendeeEmails = req.attendeeEmails != null ? req.attendeeEmails : new List<String>();

                Booking__c booking = BookingService.createBooking(bookingReq);
                res.bookingId = booking.Id;
                res.bookingUid = booking.UID__c;
                res.status = booking.Status__c;
                res.startDateTime = booking.Start_DateTime__c;
                res.endDateTime = booking.End_DateTime__c;
                res.isSuccess = true;
            } catch (SchedulingException e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(label='Event Type ID' required=true)
        public Id eventTypeId;
        @InvocableVariable(label='Start Date/Time' required=true)
        public Datetime startDateTime;
        @InvocableVariable(label='Booker Email' required=true)
        public String bookerEmail;
        @InvocableVariable(label='Booker Name' required=true)
        public String bookerName;
        @InvocableVariable(label='Attendee Emails' description='Semicolon-separated list of attendee email addresses')
        public List<String> attendeeEmails;
    }

    public class Result {
        @InvocableVariable(label='Booking ID')
        public Id bookingId;
        @InvocableVariable(label='Booking UID')
        public String bookingUid;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Start Date/Time')
        public Datetime startDateTime;
        @InvocableVariable(label='End Date/Time')
        public Datetime endDateTime;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
