@IsTest
private class IcsGeneratorTest {

    @IsTest
    static void testGenerateIcsContent() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'ICS Event', 30);
            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(30)
            );
            booking.Location__c = 'https://meet.example.com/room';
            update booking;

            Test.startTest();
            String ics = IcsGenerator.generateIcsContent(booking.Id);
            Messaging.EmailFileAttachment attachment = IcsGenerator.createIcsAttachment(booking.Id);
            Test.stopTest();

            System.assert(ics.contains('BEGIN:VCALENDAR'));
            System.assert(ics.contains(booking.UID__c));
            System.assert(ics.contains('https://meet.example.com/room'));
            System.assertNotEquals(null, attachment);
            System.assertEquals('invite.ics', attachment.getFileName());
        }
    }
}
