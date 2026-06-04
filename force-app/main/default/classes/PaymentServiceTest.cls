@IsTest
private class PaymentServiceTest {

    @IsTest
    static void testIsPaymentRequired() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c freeEvent = SchedulingTestDataFactory.createEventType(testUser.Id, 'Free Event', 30);
            Event_Type__c paidEvent = SchedulingTestDataFactory.createEventType(testUser.Id, 'Paid Event', 30);
            paidEvent.Price__c = 49.99;
            update paidEvent;

            Test.startTest();
            System.assertEquals(false, PaymentService.isPaymentRequired(freeEvent.Id));
            System.assertEquals(true, PaymentService.isPaymentRequired(paidEvent.Id));
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreatePaymentIntent() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Paid Session', 30);
            eventType.Price__c = 25;
            update eventType;

            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                Datetime.now().addDays(7),
                Datetime.now().addDays(7).addMinutes(30)
            );
            booking.Status__c = 'Pending_Payment';
            update booking;

            Test.setMock(HttpCalloutMock.class, new StripePaymentIntentMock());
            Test.startTest();
            Payment__c payment = PaymentService.createPaymentIntent(booking.Id);
            Test.stopTest();

            System.assertNotEquals(null, payment.Id);
            System.assertEquals('Pending', payment.Status__c);
            System.assertEquals('pi_test_123', payment.External_Payment_Id__c);
        }
    }

    @IsTest
    static void testCapturePayment() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Capture Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                Datetime.now().addDays(7),
                Datetime.now().addDays(7).addMinutes(30)
            );

            Payment__c payment = new Payment__c(
                Booking__c = booking.Id,
                Amount__c = 10,
                Currency_Code__c = 'USD',
                Status__c = 'Pending',
                External_Payment_Id__c = 'pi_capture_123',
                Provider__c = 'Stripe'
            );
            insert payment;

            Test.setMock(HttpCalloutMock.class, new StripeCaptureMock());
            Test.startTest();
            Payment__c captured = PaymentService.capturePayment(payment.Id);
            Test.stopTest();

            System.assertEquals('Captured', captured.Status__c);
        }
    }

    private class StripePaymentIntentMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"pi_test_123","status":"requires_payment_method"}');
            return res;
        }
    }

    private class StripeCaptureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"pi_capture_123","status":"succeeded"}');
            return res;
        }
    }
}
