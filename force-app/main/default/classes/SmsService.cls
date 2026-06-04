public with sharing class SmsService {

    public static void sendSms(String toPhone, String message) {
        if (String.isBlank(toPhone) || String.isBlank(message)) {
            return;
        }

        String normalizedPhone = toPhone.replaceAll('[^0-9+]', '');
        if (String.isBlank(normalizedPhone)) {
            throw new SchedulingException('INVALID_PHONE', 'Invalid phone number');
        }

        if (Test.isRunningTest()) {
            return;
        }

        String body = 'To=' + EncodingUtil.urlEncode(normalizedPhone, 'UTF-8') +
            '&Body=' + EncodingUtil.urlEncode(message, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Twilio_API/2010-04-01/Accounts/placeholder/Messages.json');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new SchedulingException('SMS_FAILED', 'SMS delivery failed: ' + res.getStatusCode());
        }
    }

    public static String resolvePhone(Booking__c booking, String recipient) {
        if (recipient == 'Host' || recipient == 'Both') {
            if (booking.Host__r != null && String.isNotBlank(booking.Host__r.Phone)) {
                return booking.Host__r.Phone;
            }
        }
        if (recipient == 'Attendee' || recipient == 'Both') {
            if (String.isNotBlank(booking.Booker_Phone__c)) {
                return booking.Booker_Phone__c;
            }
        }
        return null;
    }
}
