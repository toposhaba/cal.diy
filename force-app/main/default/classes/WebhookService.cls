public with sharing class WebhookService {

    @future(callout=true)
    public static void fireWebhooks(String eventName, String payloadJson) {
        List<Webhook__c> webhooks = [
            SELECT Id, URL__c, Secret__c, Events__c
            FROM Webhook__c
            WHERE Is_Active__c = true AND Events__c INCLUDES (:eventName)
            WITH USER_MODE
        ];

        for (Webhook__c webhook : webhooks) {
            try {
                sendWebhook(webhook, eventName, payloadJson);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Webhook delivery failed for ' + webhook.Id + ': ' + e.getMessage());
            }
        }
    }

    private static void sendWebhook(Webhook__c webhook, String eventName, String payloadJson) {
        Map<String, Object> envelope = new Map<String, Object>{
            'event' => eventName,
            'timestamp' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'data' => JSON.deserializeUntyped(payloadJson)
        };

        String body = JSON.serialize(envelope);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(webhook.URL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Scheduling-Event', eventName);

        if (String.isNotBlank(webhook.Secret__c)) {
            String signature = generateHmacSignature(body, webhook.Secret__c);
            req.setHeader('X-Webhook-Signature', signature);
        }

        req.setBody(body);
        req.setTimeout(10000);

        new Http().send(req);
    }

    private static String generateHmacSignature(String payload, String secret) {
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(payload),
            Blob.valueOf(secret)
        );
        return EncodingUtil.convertToHex(hmac);
    }

    public static String buildBookingPayload(Id bookingId) {
        Booking__c booking = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Location__c, Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__c, Event_Type__r.Name, Event_Type__r.Slug__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (booking == null) return '{}';

        Map<String, Object> payload = new Map<String, Object>{
            'bookingId' => booking.Id,
            'uid' => booking.UID__c,
            'title' => booking.Title__c,
            'startTime' => booking.Start_DateTime__c?.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'endTime' => booking.End_DateTime__c?.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'status' => booking.Status__c,
            'location' => booking.Location__c,
            'booker' => new Map<String, Object>{
                'email' => booking.Booker_Email__c,
                'name' => booking.Booker_Name__c
            },
            'host' => new Map<String, Object>{
                'name' => booking.Host__r?.Name,
                'email' => booking.Host__r?.Email
            },
            'eventType' => new Map<String, Object>{
                'id' => booking.Event_Type__c,
                'name' => booking.Event_Type__r?.Name,
                'slug' => booking.Event_Type__r?.Slug__c
            }
        };

        return JSON.serialize(payload);
    }
}
