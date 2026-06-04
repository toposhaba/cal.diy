@IsTest
private class WebhookServiceTest {

    @IsTest
    static void testBuildBookingPayload() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Webhook Event', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );

            Test.startTest();
            String payload = WebhookService.buildBookingPayload(booking.Id);
            Test.stopTest();

            System.assert(payload.contains(booking.UID__c));
            System.assert(payload.contains('booker@example.com'));
        }
    }

    @IsTest
    static void testFireWebhooks() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Webhook Fire', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.created', 'https://example.com/hook');

            Test.setMock(HttpCalloutMock.class, new WebhookMock());
            Test.startTest();
            WebhookService.fireWebhooks('booking.created', WebhookService.buildBookingPayload(booking.Id));
            Test.stopTest();
        }
    }

    private class WebhookMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
