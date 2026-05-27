public with sharing class CreateRecurringSeriesAction {

    @InvocableMethod(label='Create Recurring Booking Series' description='Creates a recurring series of bookings (daily, weekly, biweekly, or monthly)' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                RecurringBookingService.RecurringBookingRequest recurReq = new RecurringBookingService.RecurringBookingRequest();
                recurReq.eventTypeId = req.eventTypeId;
                recurReq.firstStartDateTime = req.firstStartDateTime;
                recurReq.bookerEmail = req.bookerEmail;
                recurReq.bookerName = req.bookerName;
                recurReq.frequency = req.frequency;
                recurReq.occurrences = req.occurrences;
                recurReq.seriesEndDate = req.seriesEndDate;

                List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(recurReq);
                res.bookingsCreated = bookings.size();
                res.firstBookingId = bookings.isEmpty() ? null : bookings[0].Id;
                res.recurringPatternId = bookings.isEmpty() ? null : bookings[0].Recurring_Pattern__c;
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
        @InvocableVariable(label='First Start Date/Time' required=true)
        public Datetime firstStartDateTime;
        @InvocableVariable(label='Booker Email' required=true)
        public String bookerEmail;
        @InvocableVariable(label='Booker Name' required=true)
        public String bookerName;
        @InvocableVariable(label='Frequency' description='Daily, Weekly, Biweekly, or Monthly' required=true)
        public String frequency;
        @InvocableVariable(label='Number of Occurrences' description='Max 52. Provide this or Series End Date.')
        public Integer occurrences;
        @InvocableVariable(label='Series End Date' description='End date for the series. Provide this or Occurrences.')
        public Date seriesEndDate;
    }

    public class Result {
        @InvocableVariable(label='Bookings Created')
        public Integer bookingsCreated;
        @InvocableVariable(label='First Booking ID')
        public Id firstBookingId;
        @InvocableVariable(label='Recurring Pattern ID')
        public Id recurringPatternId;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
