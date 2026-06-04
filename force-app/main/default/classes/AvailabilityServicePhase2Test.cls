@IsTest
private class AvailabilityServicePhase2Test {

    @IsTest
    static void testResolveMultipleDurations() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Multi Duration', 30);
            eventType.Multiple_Durations__c = '15,30,45';
            update eventType;

            List<Integer> durations = AvailabilityService.resolveDurations(eventType);
            System.assertEquals(3, durations.size());
            System.assertEquals(15, durations[0]);
        }
    }

    @IsTest
    static void testTravelScheduleTimezoneOverride() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Travel Event', 30);
            SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work Hours', true);

            Travel_Schedule__c travel = new Travel_Schedule__c(
                User__c = testUser.Id,
                Start_Date__c = Date.today().addDays(1),
                End_Date__c = Date.today().addDays(10),
                Time_Zone__c = 'Europe/London'
            );
            insert travel;

            Date targetDate = Date.today().addDays(3);
            List<AvailabilityService.TimeSlot> slots = AvailabilityService.getAvailableSlots(
                eventType.Id, targetDate, targetDate, 30
            );
            System.assertNotEquals(null, slots);
        }
    }
}
