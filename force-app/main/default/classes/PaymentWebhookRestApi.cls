@RestResource(urlMapping='/scheduling/v1/webhooks/stripe')
global with sharing class PaymentWebhookRestApi {

    @HttpPost
    global static void handleStripeWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String eventType = (String) payload.get('type');

            if (eventType == 'payment_intent.succeeded') {
                Map<String, Object> data = (Map<String, Object>) payload.get('data');
                Map<String, Object> paymentIntent = data != null ? (Map<String, Object>) data.get('object') : null;
                Map<String, Object> metadata = paymentIntent != null
                    ? (Map<String, Object>) paymentIntent.get('metadata') : null;
                String bookingIdStr = metadata != null ? (String) metadata.get('booking_id') : null;

                if (String.isNotBlank(bookingIdStr)) {
                    BookingService.completePayment((Id) bookingIdStr);
                }
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"received":true}');
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => e.getMessage()
            }));
        }
    }
}
