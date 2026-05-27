@IsTest
private class SchedulingControllerTest {

    @IsTest
    static void testGetActiveEventTypes() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            SchedulingTestDataFactory.createEventType(testUser.Id, 'Active Event', 30);
            Event_Type__c inactive = SchedulingTestDataFactory.createEventType(testUser.Id, 'Inactive Event', 60);
            inactive.Is_Active__c = false;
            update inactive;

            Test.startTest();
            List<Event_Type__c> results = SchedulingController.getActiveEventTypes(testUser.Id);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Should only return active event types');
            System.assertEquals('Active Event', results[0].Name);
        }
    }

    @IsTest
    static void testGetActiveEventTypesCurrentUser() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            SchedulingTestDataFactory.createEventType(testUser.Id, 'My Event', 30);

            Test.startTest();
            List<Event_Type__c> results = SchedulingController.getActiveEventTypes(null);
            Test.stopTest();

            System.assertEquals(1, results.size());
        }
    }

    @IsTest
    static void testGetAvailableSlots() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Slot Test', 30
            );

            Date futureDate = Date.today().addDays(7);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = SchedulingController.getAvailableSlots(
                eventType.Id,
                String.valueOf(futureDate),
                String.valueOf(futureDate)
            );
            Test.stopTest();

            System.assert(!slots.isEmpty(), 'Should have available slots');
        }
    }

    @IsTest
    static void testGetAvailableSlotsInvalidDateRange() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);

            Test.startTest();
            try {
                SchedulingController.getAvailableSlots(
                    eventType.Id,
                    String.valueOf(Date.today().addDays(10)),
                    String.valueOf(Date.today())
                );
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Start date must be before end date'));
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetAvailableSlotsExceedsMaxRange() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);

            Test.startTest();
            try {
                SchedulingController.getAvailableSlots(
                    eventType.Id,
                    String.valueOf(Date.today()),
                    String.valueOf(Date.today().addDays(90))
                );
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('cannot exceed 60 days'));
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateBookingViaController() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Controller Test', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            String startStr = startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

            Test.startTest();
            Booking__c booking = SchedulingController.createBooking(
                eventType.Id, startStr, 'booker@test.com', 'Test Booker', new List<String>()
            );
            Test.stopTest();

            System.assertNotEquals(null, booking.Id);
        }
    }

    @IsTest
    static void testCancelBookingViaController() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            Booking__c result = SchedulingController.cancelBooking(booking.Id, 'Changed plans');
            Test.stopTest();

            System.assertEquals('Cancelled', result.Status__c);
        }
    }

    @IsTest
    static void testConfirmBookingViaController() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );
            booking.Status__c = 'Pending';
            update booking;

            Test.startTest();
            Booking__c result = SchedulingController.confirmBooking(booking.Id);
            Test.stopTest();

            System.assertEquals('Accepted', result.Status__c);
        }
    }

    @IsTest
    static void testRescheduleBookingViaController() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Reschedule Test', 30
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
            String newStartStr = newStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

            Test.startTest();
            Booking__c result = SchedulingController.rescheduleBooking(booking.Id, newStartStr);
            Test.stopTest();

            System.assertEquals(newStart, result.Start_DateTime__c);
        }
    }

    @IsTest
    static void testGetMyBookings() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Datetime startDt = Datetime.now().addDays(5);
            SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            List<Booking__c> results = SchedulingController.getMyBookings(
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addDays(30))
            );
            Test.stopTest();

            System.assertEquals(1, results.size());
        }
    }

    @IsTest
    static void testGetMySchedules() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            SchedulingTestDataFactory.createSchedule(testUser.Id, 'Test Schedule', true);

            Test.startTest();
            List<Schedule__c> results = SchedulingController.getMySchedules();
            Test.stopTest();

            System.assertEquals(1, results.size());
        }
    }

    @IsTest
    static void testCreateSchedule() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Schedule__c result = SchedulingController.createSchedule(
                'New Schedule', 'America/New_York', true
            );
            Test.stopTest();

            System.assertNotEquals(null, result.Id);
            System.assertEquals('New Schedule', result.Name);
        }
    }

    @IsTest
    static void testCreateScheduleDefaultSwitch() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c first = SchedulingTestDataFactory.createSchedule(testUser.Id, 'First', true);

            Test.startTest();
            SchedulingController.createSchedule('Second', 'America/Chicago', true);
            Test.stopTest();

            first = [SELECT Is_Default__c FROM Schedule__c WHERE Id = :first.Id];
            System.assertEquals(false, first.Is_Default__c, 'Previous default should be unset');
        }
    }

    @IsTest
    static void testAddAvailability() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Test', true);

            Test.startTest();
            Availability__c result = SchedulingController.addAvailability(
                schedule.Id, 'Working_Hours', 'Monday;Tuesday;Wednesday',
                '09:00', '17:00', null
            );
            Test.stopTest();

            System.assertNotEquals(null, result.Id);
            System.assertEquals('Working_Hours', result.Record_Type__c);
        }
    }

    @IsTest
    static void testAddAvailabilityInvalidTimes() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Test', true);

            Test.startTest();
            try {
                SchedulingController.addAvailability(
                    schedule.Id, 'Working_Hours', 'Monday',
                    '17:00', '09:00', null
                );
                System.assert(false, 'Should have thrown exception');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Start time must be before end time'));
            }
            Test.stopTest();
        }
    }

    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dayName = dt.format('EEEE');
        return dayName == 'Saturday' || dayName == 'Sunday';
    }
}
