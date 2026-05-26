@IsTest
private class BookingNotificationServiceTest {

    @IsTest
    static void testSendBookingConfirmation() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Notify Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );

            Test.startTest();
            BookingNotificationService.sendBookingConfirmation(new List<Id>{ booking.Id });
            Test.stopTest();

            System.assert(true, 'Notification method should complete without error');
        }
    }

    @IsTest
    static void testSendCancellationNotice() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cancel Notify', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );
            booking.Status__c = 'Cancelled';
            booking.Cancellation_Reason__c = 'Test reason';
            update booking;

            Test.startTest();
            BookingNotificationService.sendCancellationNotice(new List<Id>{ booking.Id });
            Test.stopTest();

            System.assert(true, 'Cancellation notification should complete without error');
        }
    }

    @IsTest
    static void testSendRescheduleNotice() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Reschedule Notify', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );

            Test.startTest();
            BookingNotificationService.sendRescheduleNotice(new List<Id>{ booking.Id });
            Test.stopTest();

            System.assert(true, 'Reschedule notification should complete without error');
        }
    }

    @IsTest
    static void testSendPendingApprovalNotice() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Pending Notify', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );
            booking.Status__c = 'Pending';
            update booking;

            Test.startTest();
            BookingNotificationService.sendPendingApprovalNotice(new List<Id>{ booking.Id });
            Test.stopTest();

            System.assert(true, 'Pending notification should complete without error');
        }
    }
}
