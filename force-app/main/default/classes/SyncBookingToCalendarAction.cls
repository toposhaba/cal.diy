public with sharing class SyncBookingToCalendarAction {

    @InvocableMethod(label='Sync Booking to Calendar' description='Pushes a booking to connected external calendars (Google, Microsoft, Salesforce Events)' category='Scheduling' callout=true)
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                String externalId = CalendarIntegrationService.createExternalEvent(req.bookingId);
                res.externalEventId = externalId;
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
        @InvocableVariable(label='External Event ID')
        public String externalEventId;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
