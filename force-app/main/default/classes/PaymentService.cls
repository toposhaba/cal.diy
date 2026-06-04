public with sharing class PaymentService {

    public class PaymentCheckoutInfo {
        @AuraEnabled public Id paymentId { get; set; }
        @AuraEnabled public String clientSecret { get; set; }
        @AuraEnabled public String publishableKey { get; set; }
    }

    public static PaymentCheckoutInfo getCheckoutInfo(Id bookingId) {
        Payment__c payment = [
            SELECT Id, External_Payment_Id__c
            FROM Payment__c
            WHERE Booking__c = :bookingId AND Status__c = 'Pending'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (payment == null) {
            payment = createPaymentIntent(bookingId);
        }

        PaymentCheckoutInfo info = new PaymentCheckoutInfo();
        info.paymentId = payment.Id;
        info.publishableKey = getPublishableKey();

        if (Test.isRunningTest()) {
            info.clientSecret = 'pi_test_secret';
            return info;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Stripe_API/payment_intents/' +
            EncodingUtil.urlEncode(payment.External_Payment_Id__c, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new SchedulingException('STRIPE_ERROR', 'Unable to load payment details');
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        info.clientSecret = (String) response.get('client_secret');
        return info;
    }

    public static String getPublishableKey() {
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Stripe_Publishable_Key__c : null;
    }

    public static String getWebhookSecret() {
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Stripe_Webhook_Secret__c : null;
    }

    public static Payment__c createPaymentIntent(Id bookingId) {
        Booking__c booking = [
            SELECT Id, Event_Type__c, Event_Type__r.Price__c, Booker_Email__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Booking not found');
        }

        Decimal price = booking.Event_Type__r.Price__c;
        if (price == null || price <= 0) {
            throw new SchedulingException('NO_PRICE', 'This event type does not require payment');
        }

        Integer amountInCents = (Integer)(price * 100);

        String requestBody = 'amount=' + amountInCents +
            '&currency=usd' +
            '&receipt_email=' + EncodingUtil.urlEncode(booking.Booker_Email__c, 'UTF-8') +
            '&metadata[booking_id]=' + EncodingUtil.urlEncode(booking.Id, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Stripe_API/payment_intents');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(requestBody);
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new SchedulingException('STRIPE_ERROR', 'Payment creation failed: ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String paymentIntentId = (String) response.get('id');

        Payment__c payment = new Payment__c(
            Booking__c = booking.Id,
            Amount__c = price,
            Currency_Code__c = 'USD',
            Status__c = 'Pending',
            External_Payment_Id__c = paymentIntentId,
            Provider__c = 'Stripe'
        );
        insert as user payment;

        return payment;
    }

    public static Payment__c capturePayment(Id paymentId) {
        Payment__c payment = [
            SELECT Id, External_Payment_Id__c, Status__c
            FROM Payment__c
            WHERE Id = :paymentId AND Status__c = 'Pending'
            WITH USER_MODE
            LIMIT 1
        ];

        if (payment == null) {
            throw new SchedulingException('PAYMENT_NOT_FOUND', 'Pending payment not found');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Stripe_API/payment_intents/' +
            EncodingUtil.urlEncode(payment.External_Payment_Id__c, 'UTF-8') + '/capture');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            payment.Status__c = 'Failed';
            update as user payment;
            throw new SchedulingException('CAPTURE_FAILED', 'Payment capture failed: ' + res.getStatusCode());
        }

        payment.Status__c = 'Captured';
        update as user payment;
        return payment;
    }

    public static Payment__c refundPayment(Id paymentId) {
        Payment__c payment = [
            SELECT Id, External_Payment_Id__c, Status__c, Amount__c
            FROM Payment__c
            WHERE Id = :paymentId AND Status__c = 'Captured'
            WITH USER_MODE
            LIMIT 1
        ];

        if (payment == null) {
            throw new SchedulingException('PAYMENT_NOT_FOUND', 'Captured payment not found for refund');
        }

        String requestBody = 'payment_intent=' + EncodingUtil.urlEncode(payment.External_Payment_Id__c, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Stripe_API/refunds');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(requestBody);
        req.setTimeout(15000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new SchedulingException('REFUND_FAILED', 'Refund failed: ' + res.getStatusCode());
        }

        payment.Status__c = 'Refunded';
        update as user payment;
        return payment;
    }

    public static Boolean isPaymentRequired(Id eventTypeId) {
        Event_Type__c eventType = [
            SELECT Price__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];
        return eventType != null && eventType.Price__c != null && eventType.Price__c > 0;
    }
}
