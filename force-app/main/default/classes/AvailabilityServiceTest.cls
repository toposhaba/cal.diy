@IsTest
private class AvailabilityServiceTest {

    @IsTest
    static void testGetSchedulesForUser() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Test.startTest();
            List<Schedule__c> schedules = AvailabilityService.getSchedulesForUser(testUser.Id);
            Test.stopTest();

            System.assertEquals(1, schedules.size(), 'Should return one schedule');
            System.assertEquals('Work Hours', schedules[0].Name);
            System.assertEquals(1, schedules[0].Availabilities__r.size(), 'Should have one availability');
        }
    }

    @IsTest
    static void testGetDefaultSchedule() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            SchedulingTestDataFactory.createSchedule(testUser.Id, 'Secondary', false);
            Schedule__c defaultSchedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Default', true);

            Test.startTest();
            Schedule__c result = AvailabilityService.getDefaultSchedule(testUser.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Should find default schedule');
            System.assertEquals(defaultSchedule.Id, result.Id);
        }
    }

    @IsTest
    static void testGetSchedulesForUserWhenOwnerUserBlank() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            insert new Schedule__c(
                Name = 'UI Created',
                Time_Zone__c = 'America/New_York',
                Is_Default__c = true
            );

            Test.startTest();
            List<Schedule__c> schedules = AvailabilityService.getSchedulesForUser(testUser.Id);
            Test.stopTest();

            System.assertEquals(1, schedules.size(), 'Should include schedules owned via OwnerId');
            System.assertEquals('UI Created', schedules[0].Name);
        }
    }

    @IsTest
    static void testGetDefaultScheduleReturnsNullWhenNone() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Schedule__c result = AvailabilityService.getDefaultSchedule(testUser.Id);
            Test.stopTest();

            System.assertEquals(null, result, 'Should return null when no default schedule exists');
        }
    }

    @IsTest
    static void testGetAvailableSlots() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Consultation', 30
            );

            Date futureDate = Date.today().addDays(7);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, futureDate, futureDate
            );
            Test.stopTest();

            System.assert(!slots.isEmpty(), 'Should return available slots for a weekday');
        }
    }

    @IsTest
    static void testGetAvailableSlotsWithExistingBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(10, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Short Meeting', 60
            );

            Date futureDate = Date.today().addDays(7);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            Datetime bookingStart = Datetime.newInstance(futureDate, Time.newInstance(9, 0, 0, 0));
            Datetime bookingEnd = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            SchedulingTestDataFactory.createBooking(eventType.Id, testUser.Id, bookingStart, bookingEnd);

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, futureDate, futureDate
            );
            Test.stopTest();

            System.assertEquals(0, slots.size(), 'Should return no slots when fully booked');
        }
    }

    @IsTest
    static void testGetAvailableSlotsWithDateOverride() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Date futureDate = Date.today().addDays(7);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            SchedulingTestDataFactory.createDateOverride(
                schedule.Id, futureDate,
                Time.newInstance(10, 0, 0, 0), Time.newInstance(12, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Override Test', 30
            );

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, futureDate, futureDate
            );
            Test.stopTest();

            for (AvailabilityService.TimeSlot slot : slots) {
                Datetime slotDt = slot.startTime;
                System.assert(
                    slotDt.hour() >= 10 && slotDt.hour() < 12,
                    'Slots should only be within the override window'
                );
            }
        }
    }

    @IsTest
    static void testGetAvailableSlotsInvalidEventType() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            try {
                AvailabilityService.getAvailableSlots(
                    null, Date.today(), Date.today().addDays(7)
                );
                System.assert(false, 'Should have thrown exception');
            } catch (Exception e) {
                System.assert(true, 'Exception thrown as expected');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetAvailableSlotsNoSchedule() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(
                testUser.Id, 'No Schedule', 30
            );

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, Date.today(), Date.today().addDays(7)
            );
            Test.stopTest();

            System.assertEquals(0, slots.size(), 'Should return empty when no schedule exists');
        }
    }

    @IsTest
    static void testGetAvailableSlotsForRoundRobinEvent() {
        User host1 = SchedulingTestDataFactory.createTestUser();
        User host2 = SchedulingTestDataFactory.createTestUser();

        System.runAs(host1) {
            Schedule__c schedule1 = SchedulingTestDataFactory.createSchedule(host1.Id, 'Host 1 Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule1.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(12, 0, 0, 0)
            );

            Schedule__c schedule2 = SchedulingTestDataFactory.createSchedule(host2.Id, 'Host 2 Hours', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule2.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(13, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );

            Event_Type__c eventType = SchedulingTestDataFactory.createTeamEventType(
                host1.Id, 'Round Robin Slots', 30, 'Round_Robin', new List<Id>{ host1.Id, host2.Id }
            );

            Date startDate = Date.today().addDays(14);
            while (isWeekend(startDate)) {
                startDate = startDate.addDays(1);
            }

            Test.startTest();
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, startDate, startDate
            );
            Test.stopTest();

            System.assert(slots.size() > 0, 'Round robin event should return available slots');
        }
    }

    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dayName = dt.format('EEEE');
        return dayName == 'Saturday' || dayName == 'Sunday';
    }
}
