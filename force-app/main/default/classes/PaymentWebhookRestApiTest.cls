@IsTest
private class PaymentWebhookRestApiTest {

    @IsTest
    static void testStripeWebhookCompletesPayment() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Webhook Paid', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                Datetime.now().addDays(7),
                Datetime.now().addDays(7).addMinutes(30)
            );
            booking.Status__c = 'Pending_Payment';
            update booking;

            insert new Payment__c(
                Booking__c = booking.Id,
                Amount__c = 25,
                Currency_Code__c = 'USD',
                Status__c = 'Pending',
                External_Payment_Id__c = 'pi_webhook_123',
                Provider__c = 'Stripe'
            );

            Map<String, Object> body = new Map<String, Object>{
                'type' => 'payment_intent.succeeded',
                'data' => new Map<String, Object>{
                    'object' => new Map<String, Object>{
                        'metadata' => new Map<String, String>{
                            'booking_id' => booking.Id
                        }
                    }
                }
            };

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/webhooks/stripe';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serialize(body));
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            PaymentWebhookRestApi.handleStripeWebhook();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            Booking__c updated = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
            System.assertEquals('Accepted', updated.Status__c);
        }
    }
}
