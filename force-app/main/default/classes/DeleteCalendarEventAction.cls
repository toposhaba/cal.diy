public with sharing class DeleteCalendarEventAction {

    @InvocableMethod(label='Delete Calendar Event' description='Removes a booking from connected external calendars' category='Scheduling' callout=true)
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                CalendarIntegrationService.deleteExternalEvent(req.bookingId);
                res.isSuccess = true;
            } catch (Exception e) {
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
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
