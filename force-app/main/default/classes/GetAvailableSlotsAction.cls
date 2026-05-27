public with sharing class GetAvailableSlotsAction {

    @InvocableMethod(label='Get Available Slots' description='Calculates available booking time slots for an event type within a date range' category='Scheduling' callout=true)
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                Date startDate = req.startDate;
                Date endDate = req.endDate != null ? req.endDate : req.startDate;

                List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                    req.eventTypeId, startDate, endDate
                );

                res.slotCount = slots.size();
                res.slots = new List<String>();
                for (AvailabilityService.TimeSlot slot : slots) {
                    res.slots.add(String.valueOf(slot.startTime));
                }
                res.firstAvailableSlot = slots.isEmpty() ? null : slots[0].startTime;
                res.isSuccess = true;
            } catch (SchedulingException e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                res.slotCount = 0;
            }
            results.add(res);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(label='Event Type ID' required=true)
        public Id eventTypeId;
        @InvocableVariable(label='Start Date' required=true)
        public Date startDate;
        @InvocableVariable(label='End Date' description='Defaults to Start Date if blank')
        public Date endDate;
    }

    public class Result {
        @InvocableVariable(label='Number of Available Slots')
        public Integer slotCount;
        @InvocableVariable(label='Slot Start Times' description='List of available start times as ISO strings')
        public List<String> slots;
        @InvocableVariable(label='First Available Slot')
        public Datetime firstAvailableSlot;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
