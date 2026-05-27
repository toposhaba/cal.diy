public with sharing class SendBookingNotificationAction {

    @InvocableMethod(label='Send Booking Notification' description='Sends email notifications for bookings (confirmation, cancellation, reschedule, or pending approval)' category='Scheduling')
    public static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();

        Map<String, List<Id>> grouped = new Map<String, List<Id>>();
        for (Request req : requests) {
            String notifType = req.notificationType != null ? req.notificationType : 'Confirmation';
            if (!grouped.containsKey(notifType)) {
                grouped.put(notifType, new List<Id>());
            }
            grouped.get(notifType).add(req.bookingId);
        }

        for (String notifType : grouped.keySet()) {
            List<Id> bookingIds = grouped.get(notifType);
            try {
                switch on notifType {
                    when 'Confirmation' {
                        BookingNotificationService.sendBookingConfirmation(bookingIds);
                    }
                    when 'Cancellation' {
                        BookingNotificationService.sendCancellationNotice(bookingIds);
                    }
                    when 'Reschedule' {
                        BookingNotificationService.sendRescheduleNotice(bookingIds);
                    }
                    when 'PendingApproval' {
                        BookingNotificationService.sendPendingApprovalNotice(bookingIds);
                    }
                }
                for (Id bookingId : bookingIds) {
                    Result res = new Result();
                    res.bookingId = bookingId;
                    res.isSuccess = true;
                    results.add(res);
                }
            } catch (Exception e) {
                for (Id bookingId : bookingIds) {
                    Result res = new Result();
                    res.bookingId = bookingId;
                    res.isSuccess = false;
                    res.errorMessage = e.getMessage();
                    results.add(res);
                }
            }
        }

        return results;
    }

    public class Request {
        @InvocableVariable(label='Booking ID' required=true)
        public Id bookingId;
        @InvocableVariable(label='Notification Type' description='Confirmation, Cancellation, Reschedule, or PendingApproval' required=true)
        public String notificationType;
    }

    public class Result {
        @InvocableVariable(label='Booking ID')
        public Id bookingId;
        @InvocableVariable(label='Success')
        public Boolean isSuccess;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
