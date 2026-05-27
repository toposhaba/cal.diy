public with sharing class ConfirmBookingAction {

    @InvocableMethod(label='Confirm Booking' description='Confirms a pending booking, moving it to Accepted status' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Booking__c booking = BookingService.confirmBooking(req.bookingId);
                res.bookingId = booking.Id;
                res.status = booking.Status__c;
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
    }

    public class Result {
        @InvocableVariable(label='Booking ID')
        public Id bookingId;
        @InvocableVariable(label='Status')
        public String status;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
