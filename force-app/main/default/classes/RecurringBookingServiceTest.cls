@IsTest
private class RecurringBookingServiceTest {

    @IsTest
    static void testCreateWeeklyRecurringSeries() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Weekly Sync', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'client@example.com';
            request.bookerName = 'Regular Client';
            request.frequency = 'Weekly';
            request.occurrences = 4;

            Test.startTest();
            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            Test.stopTest();

            System.assertEquals(4, bookings.size(), 'Should create 4 weekly bookings');

            List<Recurring_Pattern__c> patterns = [SELECT Id FROM Recurring_Pattern__c];
            System.assertEquals(1, patterns.size(), 'Should create one pattern');

            for (Booking__c b : bookings) {
                System.assertEquals(patterns[0].Id, b.Recurring_Pattern__c);
            }
        }
    }

    @IsTest
    static void testCreateDailyRecurringSeries() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Daily Check', 15);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'daily@example.com';
            request.bookerName = 'Daily Client';
            request.frequency = 'Daily';
            request.occurrences = 5;

            Test.startTest();
            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            Test.stopTest();

            System.assertEquals(5, bookings.size());

            Datetime first = bookings[0].Start_DateTime__c;
            Datetime second = bookings[1].Start_DateTime__c;
            Long diffMs = second.getTime() - first.getTime();
            System.assertEquals(86400000, diffMs, 'Should be 1 day apart');
        }
    }

    @IsTest
    static void testCreateRecurringSeriesWithEndDate() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Bounded', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'bounded@example.com';
            request.bookerName = 'Bounded Client';
            request.frequency = 'Weekly';
            request.occurrences = 52;
            request.seriesEndDate = Date.today().addDays(21);

            Test.startTest();
            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            Test.stopTest();

            System.assert(bookings.size() <= 3, 'Should be limited by end date');
            for (Booking__c b : bookings) {
                System.assert(b.Start_DateTime__c.date() <= request.seriesEndDate, 'No booking should exceed end date');
            }
        }
    }

    @IsTest
    static void testCancelRecurringSeries() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cancel Test', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'cancel@example.com';
            request.bookerName = 'Cancel Client';
            request.frequency = 'Weekly';
            request.occurrences = 3;

            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            Id patternId = bookings[0].Recurring_Pattern__c;

            Test.startTest();
            RecurringBookingService.cancelRecurringSeries(patternId, 'No longer needed', false);
            Test.stopTest();

            List<Booking__c> cancelled = [
                SELECT Status__c FROM Booking__c WHERE Recurring_Pattern__c = :patternId
            ];
            for (Booking__c b : cancelled) {
                System.assertEquals('Cancelled', b.Status__c);
            }
        }
    }

    @IsTest
    static void testCancelFutureOnlyRecurringSeries() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Future Only', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(1);
            request.bookerEmail = 'future@example.com';
            request.bookerName = 'Future Client';
            request.frequency = 'Weekly';
            request.occurrences = 4;

            List<Booking__c> bookings = RecurringBookingService.createRecurringSeries(request);
            Id patternId = bookings[0].Recurring_Pattern__c;

            Test.startTest();
            RecurringBookingService.cancelRecurringSeries(patternId, 'Partial cancel', true);
            Test.stopTest();

            List<Booking__c> results = [
                SELECT Status__c, Start_DateTime__c
                FROM Booking__c
                WHERE Recurring_Pattern__c = :patternId AND Status__c = 'Cancelled'
            ];
            System.assert(!results.isEmpty(), 'Should have cancelled future bookings');
        }
    }

    @IsTest
    static void testGetSeriesBookings() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Series', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'series@example.com';
            request.bookerName = 'Series Client';
            request.frequency = 'Weekly';
            request.occurrences = 3;

            List<Booking__c> created = RecurringBookingService.createRecurringSeries(request);
            Id patternId = created[0].Recurring_Pattern__c;

            Test.startTest();
            List<Booking__c> series = RecurringBookingService.getSeriesBookings(patternId);
            Test.stopTest();

            System.assertEquals(3, series.size());
        }
    }

    @IsTest
    static void testInvalidRequestMissingFields() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();

            Test.startTest();
            try {
                RecurringBookingService.createRecurringSeries(request);
                System.assert(false, 'Should have thrown exception');
            } catch (SchedulingException e) {
                System.assertEquals('INVALID_INPUT', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testExceedsMaxOccurrences() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Too Many', 30);

            RecurringBookingService.RecurringBookingRequest request = new RecurringBookingService.RecurringBookingRequest();
            request.eventTypeId = eventType.Id;
            request.firstStartDateTime = Datetime.now().addDays(7);
            request.bookerEmail = 'max@example.com';
            request.bookerName = 'Max Client';
            request.frequency = 'Daily';
            request.occurrences = 100;

            Test.startTest();
            try {
                RecurringBookingService.createRecurringSeries(request);
                System.assert(false, 'Should have thrown exception');
            } catch (SchedulingException e) {
                System.assert(e.getMessage().contains('52'));
            }
            Test.stopTest();
        }
    }
}
