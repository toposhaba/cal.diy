public with sharing class CancelRecurringSeriesAction {

    @InvocableMethod(label='Cancel Recurring Series' description='Cancels all or future bookings in a recurring series' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Boolean futureOnly = req.futureOnly != null ? req.futureOnly : false;
                RecurringBookingService.cancelRecurringSeries(req.recurringPatternId, req.reason, futureOnly);
                res.isSuccess = true;
                res.recurringPatternId = req.recurringPatternId;
            } catch (SchedulingException e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(label='Recurring Pattern ID' required=true)
        public Id recurringPatternId;
        @InvocableVariable(label='Cancellation Reason')
        public String reason;
        @InvocableVariable(label='Future Only' description='If true, only cancels bookings that have not yet occurred')
        public Boolean futureOnly;
    }

    public class Result {
        @InvocableVariable(label='Recurring Pattern ID')
        public Id recurringPatternId;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
