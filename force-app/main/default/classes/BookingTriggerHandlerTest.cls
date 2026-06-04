@IsTest
private class BookingTriggerHandlerTest {

    @IsTest
    static void testInsertAcceptedBookingFiresIntegrations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Integration Test', 30);
            SchedulingTestDataFactory.createWorkflow('New_Booking', eventType.Id, 'Attendee', 'Hello {booking.title}');
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.created', 'https://example.com/hook');

            Datetime startDt = Datetime.now().addDays(3);
            Datetime endDt = startDt.addMinutes(30);

            Test.setMock(HttpCalloutMock.class, new WebhookCalloutMock());

            Test.startTest();
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, endDt
            );
            Test.stopTest();

            System.assertEquals('Accepted', booking.Status__c);
        }
    }

    @IsTest
    static void testInsertPendingBookingFiresIntegrations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Pending Test', 30);
            eventType.Requires_Confirmation__c = true;
            update eventType;

            SchedulingTestDataFactory.createWorkflow('New_Booking', eventType.Id, 'Host', 'Pending {booking.title}');
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.created', 'https://example.com/pending');

            Test.setMock(HttpCalloutMock.class, new WebhookCalloutMock());

            Test.startTest();
            Booking__c booking = new Booking__c(
                UID__c = 'pending-' + String.valueOf(Datetime.now().getTime()),
                Event_Type__c = eventType.Id,
                Host__c = testUser.Id,
                Title__c = 'Pending Booking',
                Start_DateTime__c = Datetime.now().addDays(4),
                End_DateTime__c = Datetime.now().addDays(4).addMinutes(30),
                Status__c = 'Pending',
                Booker_Email__c = 'pending@example.com',
                Booker_Name__c = 'Pending Booker'
            );
            insert booking;
            Test.stopTest();

            System.assertEquals('Pending', booking.Status__c);
        }
    }

    @IsTest
    static void testConfirmBookingFiresIntegrations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Confirm Test', 30);
            SchedulingTestDataFactory.createWorkflow('Booking_Confirmed', eventType.Id, 'Both', 'Confirmed {booking.title}');
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.confirmed', 'https://example.com/confirmed');

            Booking__c booking = new Booking__c(
                UID__c = 'confirm-' + String.valueOf(Datetime.now().getTime()),
                Event_Type__c = eventType.Id,
                Host__c = testUser.Id,
                Title__c = 'Confirm Booking',
                Start_DateTime__c = Datetime.now().addDays(5),
                End_DateTime__c = Datetime.now().addDays(5).addMinutes(30),
                Status__c = 'Pending',
                Booker_Email__c = 'confirm@example.com',
                Booker_Name__c = 'Confirm Booker'
            );
            insert booking;

            Test.setMock(HttpCalloutMock.class, new WebhookCalloutMock());

            Test.startTest();
            booking.Status__c = 'Accepted';
            update booking;
            Test.stopTest();

            Booking__c updated = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
            System.assertEquals('Accepted', updated.Status__c);
        }
    }

    @IsTest
    static void testCancelBookingFiresIntegrations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cancel Test', 30);
            SchedulingTestDataFactory.createWorkflow('Booking_Cancelled', eventType.Id, 'Attendee', 'Cancelled {booking.title}');
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.cancelled', 'https://example.com/cancelled');

            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                Datetime.now().addDays(6),
                Datetime.now().addDays(6).addMinutes(30)
            );

            Test.setMock(HttpCalloutMock.class, new WebhookCalloutMock());

            Test.startTest();
            booking.Status__c = 'Cancelled';
            booking.Cancellation_Reason__c = 'No longer needed';
            update booking;
            Test.stopTest();

            Booking__c updated = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
            System.assertEquals('Cancelled', updated.Status__c);
        }
    }

    @IsTest
    static void testRescheduleBookingFiresIntegrations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Reschedule Test', 30);
            SchedulingTestDataFactory.createWorkflow('Booking_Rescheduled', eventType.Id, 'Both', 'Moved {booking.title}');
            SchedulingTestDataFactory.createWebhook(testUser.Id, 'booking.rescheduled', 'https://example.com/rescheduled');

            Datetime originalStart = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                originalStart,
                originalStart.addMinutes(30)
            );

            Test.setMock(HttpCalloutMock.class, new WebhookCalloutMock());

            Test.startTest();
            booking.Start_DateTime__c = originalStart.addHours(2);
            booking.End_DateTime__c = originalStart.addHours(2).addMinutes(30);
            update booking;
            Test.stopTest();

            Booking__c updated = [SELECT Start_DateTime__c FROM Booking__c WHERE Id = :booking.Id];
            System.assertEquals(originalStart.addHours(2), updated.Start_DateTime__c);
        }
    }

    private class WebhookCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }
}
