@IsTest
private class SmsServiceTest {

    private class TwilioMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"sid":"SM123"}');
            return res;
        }
    }

    @IsTest
    static void testSendSmsInTestContext() {
        User testUser = SchedulingTestDataFactory.createTestUser();
        System.runAs(testUser) {
            SmsService.sendSms('+15551234567', 'Reminder message');
        }
    }

    @IsTest
    static void testResolvePhone() {
        User testUser = SchedulingTestDataFactory.createTestUser();
        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'SMS Event', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(2), Datetime.now().addDays(2).addMinutes(30)
            );
            booking.Booker_Phone__c = '+15559876543';
            update booking;

            booking = [
                SELECT Booker_Phone__c, Host__r.Phone
                FROM Booking__c
                WHERE Id = :booking.Id
            ];

            System.assertEquals(
                '+15559876543',
                SmsService.resolvePhone(booking, 'Attendee')
            );
        }
    }
}
