@IsTest
private class BookingEnrichmentServiceTest {

    @IsTest
    static void testEnsureMeetingLink() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Video Event', 30);
            eventType.Video_Provider__c = 'Zoom';
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(30)
            );

            Test.startTest();
            BookingEnrichmentService.ensureMeetingLink(booking.Id);
            Test.stopTest();

            Booking__c updated = [
                SELECT Location__c
                FROM Booking__c
                WHERE Id = :booking.Id
            ];
            System.assert(updated.Location__c.startsWith('https://meet.example.com/'));
        }
    }
}
