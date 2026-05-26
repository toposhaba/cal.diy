@IsTest
private class BookingServiceTest {

    @IsTest
    static void testCreateBookingSuccess() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Meeting', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventType.Id;
            request.startDateTime = startDt;
            request.bookerEmail = 'client@example.com';
            request.bookerName = 'Jane Client';
            request.attendeeEmails = new List<String>{ 'guest@example.com' };

            Test.startTest();
            Booking__c booking = BookingService.createBooking(request);
            Test.stopTest();

            System.assertNotEquals(null, booking.Id, 'Booking should be created');
            System.assertEquals('Accepted', booking.Status__c);
            System.assertNotEquals(null, booking.UID__c, 'UID should be generated');

            List<Attendee__c> attendees = [SELECT Id FROM Attendee__c WHERE Booking__c = :booking.Id];
            System.assertEquals(1, attendees.size(), 'Should create one attendee');
        }
    }

    @IsTest
    static void testCreateBookingRequiresConfirmation() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Confirmed Meeting', 30
            );
            eventType.Requires_Confirmation__c = true;
            update eventType;

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventType.Id;
            request.startDateTime = startDt;
            request.bookerEmail = 'client@example.com';
            request.bookerName = 'Jane Client';

            Test.startTest();
            Booking__c booking = BookingService.createBooking(request);
            Test.stopTest();

            System.assertEquals('Pending', booking.Status__c, 'Should be pending when confirmation required');
        }
    }

    @IsTest
    static void testCreateBookingInvalidEmail() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventType.Id;
            request.startDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'not-an-email';
            request.bookerName = 'Test';

            Test.startTest();
            try {
                BookingService.createBooking(request);
                System.assert(false, 'Should have thrown exception for invalid email');
            } catch (SchedulingException e) {
                System.assertEquals('INVALID_INPUT', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateBookingMissingFields() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            BookingService.BookingRequest request = new BookingService.BookingRequest();

            Test.startTest();
            try {
                BookingService.createBooking(request);
                System.assert(false, 'Should have thrown exception');
            } catch (SchedulingException e) {
                System.assertEquals('INVALID_INPUT', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateBookingInsufficientNotice() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventType.Id;
            request.startDateTime = Datetime.now().addMinutes(10);
            request.bookerEmail = 'client@example.com';
            request.bookerName = 'Jane Client';

            Test.startTest();
            try {
                BookingService.createBooking(request);
                System.assert(false, 'Should have thrown exception for insufficient notice');
            } catch (SchedulingException e) {
                System.assertEquals('INSUFFICIENT_NOTICE', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateBookingSlotConflict() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Meeting', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            Datetime endDt = startDt.addMinutes(30);

            SchedulingTestDataFactory.createBooking(eventType.Id, testUser.Id, startDt, endDt);

            BookingService.BookingRequest request = new BookingService.BookingRequest();
            request.eventTypeId = eventType.Id;
            request.startDateTime = startDt;
            request.bookerEmail = 'another@example.com';
            request.bookerName = 'Another Client';

            Test.startTest();
            try {
                BookingService.createBooking(request);
                System.assert(false, 'Should have thrown exception for slot conflict');
            } catch (SchedulingException e) {
                System.assertEquals('SLOT_UNAVAILABLE', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCancelBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            Booking__c cancelled = BookingService.cancelBooking(booking.Id, 'Schedule conflict');
            Test.stopTest();

            System.assertEquals('Cancelled', cancelled.Status__c);
            System.assertEquals('Schedule conflict', cancelled.Cancellation_Reason__c);
        }
    }

    @IsTest
    static void testCancelAlreadyCancelledBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );
            booking.Status__c = 'Cancelled';
            update booking;

            Test.startTest();
            try {
                BookingService.cancelBooking(booking.Id, 'Again');
                System.assert(false, 'Should have thrown exception');
            } catch (SchedulingException e) {
                System.assertEquals('ALREADY_CANCELLED', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testConfirmBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );
            booking.Status__c = 'Pending';
            update booking;

            Test.startTest();
            Booking__c confirmed = BookingService.confirmBooking(booking.Id);
            Test.stopTest();

            System.assertEquals('Accepted', confirmed.Status__c);
        }
    }

    @IsTest
    static void testRescheduleBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Meeting', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Datetime newStart = Datetime.newInstance(futureDate, Time.newInstance(14, 0, 0, 0));

            Test.startTest();
            Booking__c rescheduled = BookingService.rescheduleBooking(booking.Id, newStart);
            Test.stopTest();

            System.assertEquals(newStart, rescheduled.Start_DateTime__c);
            System.assertEquals(newStart.addMinutes(30), rescheduled.End_DateTime__c);
        }
    }

    @IsTest
    static void testGetBookingsForHost() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meeting', 30);
            Datetime startDt = Datetime.now().addDays(3);
            SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            List<Booking__c> bookings = BookingService.getBookingsForHost(
                testUser.Id, Date.today(), Date.today().addDays(30)
            );
            Test.stopTest();

            System.assertEquals(1, bookings.size(), 'Should return one booking');
        }
    }

    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dayName = dt.format('EEEE');
        return dayName == 'Saturday' || dayName == 'Sunday';
    }
}
