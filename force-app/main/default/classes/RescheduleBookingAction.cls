public with sharing class RescheduleBookingAction {

    @InvocableMethod(label='Reschedule Booking' description='Reschedules an existing booking to a new date/time' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Booking__c booking = BookingService.rescheduleBooking(req.bookingId, req.newStartDateTime);
                res.bookingId = booking.Id;
                res.newStartDateTime = booking.Start_DateTime__c;
                res.newEndDateTime = booking.End_DateTime__c;
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
        @InvocableVariable(label='Booking ID' required=true)
        public Id bookingId;
        @InvocableVariable(label='New Start Date/Time' required=true)
        public Datetime newStartDateTime;
    }

    public class Result {
        @InvocableVariable(label='Booking ID')
        public Id bookingId;
        @InvocableVariable(label='New Start Date/Time')
        public Datetime newStartDateTime;
        @InvocableVariable(label='New End Date/Time')
        public Datetime newEndDateTime;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
