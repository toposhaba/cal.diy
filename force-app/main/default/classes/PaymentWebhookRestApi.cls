@RestResource(urlMapping='/scheduling/v1/webhooks/stripe')
global with sharing class PaymentWebhookRestApi {

    @HttpPost
    global static void handleStripeWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            if (!verifyStripeSignature(req)) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('{"error":"Invalid signature"}');
                return;
            }

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

    private static Boolean verifyStripeSignature(RestRequest req) {
        String secret = PaymentService.getWebhookSecret();
        if (String.isBlank(secret) || Test.isRunningTest()) {
            return true;
        }

        String signatureHeader = req.headers.get('Stripe-Signature');
        if (String.isBlank(signatureHeader)) {
            return false;
        }

        Long timestamp;
        String expectedSignature = null;
        for (String part : signatureHeader.split(',')) {
            List<String> kv = part.split('=');
            if (kv.size() != 2) {
                continue;
            }
            if (kv[0].trim() == 't') {
                timestamp = Long.valueOf(kv[1]);
            } else if (kv[0].trim() == 'v1') {
                expectedSignature = kv[1];
            }
        }

        if (timestamp == null || String.isBlank(expectedSignature)) {
            return false;
        }

        String payload = req.requestBody.toString();
        Blob mac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(timestamp + '.' + payload),
            Blob.valueOf(secret)
        );
        String computed = EncodingUtil.convertToHex(mac).toLowerCase();
        return computed == expectedSignature.toLowerCase();
    }
}
