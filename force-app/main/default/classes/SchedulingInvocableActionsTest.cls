@IsTest
private class SchedulingInvocableActionsTest {

    @IsTest
    static void testSendBookingNotificationAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Notify', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );

            SendBookingNotificationAction.Request req = new SendBookingNotificationAction.Request();
            req.bookingId = booking.Id;
            req.notificationType = 'Confirmation';

            Test.startTest();
            List<SendBookingNotificationAction.Result> results = SendBookingNotificationAction.execute(
                new List<SendBookingNotificationAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    static void testRescheduleBookingAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Action Reschedule', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            RescheduleBookingAction.Request req = new RescheduleBookingAction.Request();
            req.bookingId = booking.Id;
            req.newStartDateTime = Datetime.newInstance(futureDate, Time.newInstance(14, 0, 0, 0));

            Test.startTest();
            List<RescheduleBookingAction.Result> results = RescheduleBookingAction.execute(
                new List<RescheduleBookingAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    static void testCreateRecurringSeriesAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Weekly Sync', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            CreateRecurringSeriesAction.Request req = new CreateRecurringSeriesAction.Request();
            req.eventTypeId = eventType.Id;
            req.firstStartDateTime = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            req.bookerEmail = 'series@example.com';
            req.bookerName = 'Series Booker';
            req.frequency = 'Weekly';
            req.occurrences = 3;

            Test.startTest();
            List<CreateRecurringSeriesAction.Result> results = CreateRecurringSeriesAction.execute(
                new List<CreateRecurringSeriesAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
            System.assertEquals(3, results[0].bookingsCreated);
        }
    }

    @IsTest
    static void testCancelRecurringSeriesAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Series', 30);
            Recurring_Pattern__c pattern = new Recurring_Pattern__c(
                Frequency__c = 'Weekly',
                Occurrences__c = 2,
                Event_Type__c = eventType.Id
            );
            insert pattern;

            Datetime start = Datetime.now().addDays(7);
            insert new Booking__c(
                UID__c = 'series-1',
                Event_Type__c = eventType.Id,
                Host__c = testUser.Id,
                Title__c = 'Series Booking',
                Start_DateTime__c = start,
                End_DateTime__c = start.addMinutes(30),
                Status__c = 'Accepted',
                Booker_Email__c = 'series@example.com',
                Booker_Name__c = 'Series Booker',
                Recurring_Pattern__c = pattern.Id
            );

            CancelRecurringSeriesAction.Request req = new CancelRecurringSeriesAction.Request();
            req.recurringPatternId = pattern.Id;
            req.reason = 'Series cancelled';
            req.futureOnly = false;

            Test.startTest();
            List<CancelRecurringSeriesAction.Result> results = CancelRecurringSeriesAction.execute(
                new List<CancelRecurringSeriesAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    static void testSyncBookingToCalendarAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Calendar Sync', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );

            SyncBookingToCalendarAction.Request req = new SyncBookingToCalendarAction.Request();
            req.bookingId = booking.Id;

            Test.startTest();
            List<SyncBookingToCalendarAction.Result> results = SyncBookingToCalendarAction.execute(
                new List<SyncBookingToCalendarAction.Request>{ req }
            );
            Test.stopTest();

            System.assertNotEquals(null, results[0]);
        }
    }

    @IsTest
    static void testDeleteCalendarEventAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Delete Event', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );

            DeleteCalendarEventAction.Request req = new DeleteCalendarEventAction.Request();
            req.bookingId = booking.Id;

            Test.startTest();
            List<DeleteCalendarEventAction.Result> results = DeleteCalendarEventAction.execute(
                new List<DeleteCalendarEventAction.Request>{ req }
            );
            Test.stopTest();

            System.assertNotEquals(null, results[0]);
        }
    }

    @IsTest
    static void testCreateBookingAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Action Create', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            CreateBookingAction.Request req = new CreateBookingAction.Request();
            req.eventTypeId = eventType.Id;
            req.startDateTime = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            req.bookerEmail = 'action@example.com';
            req.bookerName = 'Action Booker';

            Test.startTest();
            List<CreateBookingAction.Result> results = CreateBookingAction.execute(
                new List<CreateBookingAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
            System.assertNotEquals(null, results[0].bookingId);
        }
    }

    @IsTest
    static void testGetAvailableSlotsAction() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Action Slots', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            GetAvailableSlotsAction.Request req = new GetAvailableSlotsAction.Request();
            req.eventTypeId = eventType.Id;
            req.startDate = futureDate;
            req.endDate = futureDate;

            Test.startTest();
            List<GetAvailableSlotsAction.Result> results = GetAvailableSlotsAction.execute(
                new List<GetAvailableSlotsAction.Request>{ req }
            );
            Test.stopTest();

            System.assertEquals(true, results[0].isSuccess);
            System.assert(results[0].slotCount > 0);
        }
    }

    @IsTest
    static void testCancelAndConfirmBookingActions() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Action Lifecycle', 30);
            Booking__c pending = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
            );
            pending.Status__c = 'Pending';
            update pending;

            ConfirmBookingAction.Request confirmReq = new ConfirmBookingAction.Request();
            confirmReq.bookingId = pending.Id;

            Test.startTest();
            List<ConfirmBookingAction.Result> confirmResults = ConfirmBookingAction.execute(
                new List<ConfirmBookingAction.Request>{ confirmReq }
            );

            CancelBookingAction.Request cancelReq = new CancelBookingAction.Request();
            cancelReq.bookingId = pending.Id;
            cancelReq.reason = 'Changed plans';
            List<CancelBookingAction.Result> cancelResults = CancelBookingAction.execute(
                new List<CancelBookingAction.Request>{ cancelReq }
            );
            Test.stopTest();

            System.assertEquals(true, confirmResults[0].isSuccess);
            System.assertEquals(true, cancelResults[0].isSuccess);
        }
    }

    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dayName = dt.format('EEEE');
        return dayName == 'Saturday' || dayName == 'Sunday';
    }
}
