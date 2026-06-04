@IsTest
private class CalendarSyncBatchTest {

    @IsTest
    static void testBatchSyncsUnsyncedBookings() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Sync Batch', 30);
            Calendar_Connection__c connection = SchedulingTestDataFactory.createCalendarConnection(
                testUser.Id, 'Google', true
            );

            Datetime startDt = Datetime.now().addDays(2);
            SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.setMock(HttpCalloutMock.class, new CalendarCalloutMock());

            Test.startTest();
            Database.executeBatch(new CalendarSyncBatch(), 10);
            Test.stopTest();

            Calendar_Connection__c updated = [
                SELECT Last_Sync__c
                FROM Calendar_Connection__c
                WHERE Id = :connection.Id
            ];
            System.assertNotEquals(null, updated.Last_Sync__c);
        }
    }

    @IsTest
    static void testSchedulableExecutesBatch() {
        Test.startTest();
        String jobId = System.schedule('TestCalSync', '0 0 0 1 1 ? 2099', new CalendarSyncSchedulable());
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    private class CalendarCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"ext-event-123"}');
            return res;
        }
    }
}
