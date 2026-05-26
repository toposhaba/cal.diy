@IsTest
private class CalendarIntegrationServiceTest {

    @IsTest
    static void testGetExternalBusyTimesNoConnections() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            List<CalendarIntegrationService.BusySlot> slots =
                CalendarIntegrationService.getExternalBusyTimes(
                    testUser.Id, Datetime.now(), Datetime.now().addDays(7)
                );
            Test.stopTest();

            System.assertEquals(0, slots.size(), 'No connections should return empty');
        }
    }

    @IsTest
    static void testGetExternalBusyTimesSalesforceProvider() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = new Calendar_Connection__c(
                Name = 'Salesforce Calendar',
                Owner_User__c = testUser.Id,
                Provider__c = 'Salesforce',
                Is_Active__c = true,
                Check_For_Conflicts__c = true
            );
            insert conn;

            Event sfEvent = new Event(
                Subject = 'Existing Meeting',
                StartDateTime = Datetime.now().addDays(1),
                EndDateTime = Datetime.now().addDays(1).addHours(1),
                OwnerId = testUser.Id
            );
            insert sfEvent;

            Test.startTest();
            List<CalendarIntegrationService.BusySlot> slots =
                CalendarIntegrationService.getExternalBusyTimes(
                    testUser.Id, Datetime.now(), Datetime.now().addDays(7)
                );
            Test.stopTest();

            System.assertEquals(1, slots.size(), 'Should return SF event as busy slot');
            System.assertEquals('Existing Meeting', slots[0].title);
        }
    }

    @IsTest
    static void testCreateExternalEventSalesforceProvider() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = new Calendar_Connection__c(
                Name = 'Salesforce Calendar',
                Owner_User__c = testUser.Id,
                Provider__c = 'Salesforce',
                Is_Active__c = true,
                Push_Events_To__c = true
            );
            insert conn;

            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            String externalId = CalendarIntegrationService.createExternalEvent(booking.Id);
            Test.stopTest();

            System.assertNotEquals(null, externalId, 'Should return external event ID');

            List<Event> events = [SELECT Id, Subject FROM Event WHERE OwnerId = :testUser.Id AND Subject = :booking.Title__c];
            System.assertEquals(1, events.size(), 'Should create SF Event');
        }
    }

    @IsTest
    static void testDeleteExternalEventSalesforceProvider() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = new Calendar_Connection__c(
                Name = 'Salesforce Calendar',
                Owner_User__c = testUser.Id,
                Provider__c = 'Salesforce',
                Is_Active__c = true,
                Push_Events_To__c = true
            );
            insert conn;

            Event sfEvent = new Event(
                Subject = 'To Delete',
                StartDateTime = Datetime.now().addDays(7),
                EndDateTime = Datetime.now().addDays(7).addHours(1),
                OwnerId = testUser.Id
            );
            insert sfEvent;

            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Datetime startDt = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );
            booking.External_Event_Id__c = sfEvent.Id;
            update booking;

            Test.startTest();
            CalendarIntegrationService.deleteExternalEvent(booking.Id);
            Test.stopTest();

            Booking__c updatedBooking = [SELECT External_Event_Id__c FROM Booking__c WHERE Id = :booking.Id];
            System.assertEquals(null, updatedBooking.External_Event_Id__c);
        }
    }

    @IsTest
    static void testGoogleCalendarCalloutMock() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = new Calendar_Connection__c(
                Name = 'Google',
                Owner_User__c = testUser.Id,
                Provider__c = 'Google',
                Calendar_Id__c = 'primary',
                Is_Active__c = true,
                Check_For_Conflicts__c = true
            );
            insert conn;

            Test.setMock(HttpCalloutMock.class, new GoogleCalendarMock());

            Test.startTest();
            List<CalendarIntegrationService.BusySlot> slots =
                CalendarIntegrationService.getExternalBusyTimes(
                    testUser.Id, Datetime.now(), Datetime.now().addDays(7)
                );
            Test.stopTest();

            System.assertEquals(1, slots.size(), 'Should parse Google event');
            System.assertEquals('Team Standup', slots[0].title);
        }
    }

    @IsTest
    static void testMicrosoftGraphCalloutMock() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = new Calendar_Connection__c(
                Name = 'Outlook',
                Owner_User__c = testUser.Id,
                Provider__c = 'Microsoft',
                Is_Active__c = true,
                Check_For_Conflicts__c = true
            );
            insert conn;

            Test.setMock(HttpCalloutMock.class, new MicrosoftGraphMock());

            Test.startTest();
            List<CalendarIntegrationService.BusySlot> slots =
                CalendarIntegrationService.getExternalBusyTimes(
                    testUser.Id, Datetime.now(), Datetime.now().addDays(7)
                );
            Test.stopTest();

            System.assertEquals(1, slots.size(), 'Should parse Microsoft event');
            System.assertEquals('Project Review', slots[0].title);
        }
    }

    private class GoogleCalendarMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"items":[{"status":"confirmed","summary":"Team Standup","start":{"dateTime":"2026-06-01T09:00:00Z"},"end":{"dateTime":"2026-06-01T09:30:00Z"}}]}');
            return res;
        }
    }

    private class MicrosoftGraphMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"value":[{"subject":"Project Review","showAs":"busy","start":{"dateTime":"2026-06-01T14:00:00"},"end":{"dateTime":"2026-06-01T15:00:00"}}]}');
            return res;
        }
    }
}
