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

            System.assertEquals(2, BookingNotificationService.buildConfirmationEmailCount(new List<Id>{ booking.Id }));
        }
    }

    @IsTest
    static void testSendSeatConfirmationSkipsBlankEmail() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Blank Email Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );

            Test.startTest();
            BookingNotificationService.sendSeatConfirmation(booking.Id, '', 'No Email');
            Test.stopTest();

            System.assertEquals(0, Limits.getEmailInvocations());
        }
    }

    @IsTest
    static void testSendSeatConfirmation() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Seat Notify', 60);
            eventType.Seats_Per_Slot__c = 5;
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(60)
            );

            Test.startTest();
            BookingNotificationService.sendSeatConfirmation(booking.Id, 'seat@example.com', 'Seat Booker');
            Test.stopTest();

            System.assertEquals(
                1,
                BookingNotificationService.buildSeatConfirmationEmailCount(booking.Id, 'seat@example.com')
            );
        }
    }

    @IsTest
    static void testSendBookingConfirmationAsBookerUser() {
        User hostUser = SchedulingTestDataFactory.createTestUser();
        User bookerUser = SchedulingTestDataFactory.createBookerUser();
        Id bookingId;

        System.runAs(hostUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(hostUser.Id, 'Booker Access Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, hostUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );
            bookingId = booking.Id;
        }

        System.runAs(bookerUser) {
            Test.startTest();
            BookingNotificationService.sendBookingConfirmation(new List<Id>{ bookingId });
            Test.stopTest();

            System.assertEquals(2, BookingNotificationService.buildConfirmationEmailCount(new List<Id>{ bookingId }));
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

    @IsTest
    static void testResetOrgWideEmailCacheForTest() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cache Reset Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );

            BookingNotificationService.resetOrgWideEmailCacheForTest();
            System.assertEquals(2, BookingNotificationService.buildConfirmationEmailCount(new List<Id>{ booking.Id }));
        }
    }

    @IsTest
    static void testCalendarLinksInConfirmationHtml() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Calendar Link Test', 30);
            Datetime start = Datetime.newInstanceGmt(2026, 6, 15, 14, 0, 0);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(30)
            );
            booking.Location__c = 'Room A & B';
            booking.Title__c = 'Strategy Session';
            update booking;

            booking = [
                SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c, Location__c,
                       Booker_Email__c, Booker_Name__c, Host__r.Name, Host__r.Email,
                       Event_Type__r.Name
                FROM Booking__c
                WHERE Id = :booking.Id
            ];

            String html = BookingNotificationService.buildBookerConfirmationHtml(booking);
            String googleUrl = BookingNotificationService.buildGoogleCalendarUrl(booking);
            String outlookUrl = BookingNotificationService.buildOutlookCalendarUrl(booking);

            System.assert(html.contains('Add to Google Calendar'), 'Expected Google Calendar button');
            System.assert(html.contains('Add to Outlook'), 'Expected Outlook button');
            System.assert(html.contains(googleUrl.escapeHtml4()), 'Expected encoded Google URL in HTML');
            System.assert(html.contains(outlookUrl.escapeHtml4()), 'Expected encoded Outlook URL in HTML');
            System.assert(googleUrl.startsWith('https://calendar.google.com/calendar/render?action=TEMPLATE'));
            System.assert(googleUrl.contains('Strategy+Session') || googleUrl.contains('Strategy%20Session'));
            System.assert(googleUrl.contains('20260615T140000Z%2F20260615T143000Z') || googleUrl.contains('20260615T140000Z/20260615T143000Z'));
            System.assert(googleUrl.contains('Room+A+%26+B') || googleUrl.contains('Room%20A%20%26%20B'));
            System.assert(outlookUrl.startsWith('https://outlook.office.com/calendar/0/deeplink/compose'));
            System.assert(outlookUrl.contains('2026-06-15T14%3A00%3A00Z'));
            System.assert(outlookUrl.contains('2026-06-15T14%3A30%3A00Z'));

            String hostHtml = BookingNotificationService.buildHostNotificationHtml(booking);
            System.assert(hostHtml.contains('Add to Google Calendar'));
            System.assert(hostHtml.contains('Add to Outlook'));
        }
    }
}
