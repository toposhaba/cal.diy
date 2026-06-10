@IsTest
private class MeetingOptionsServiceTest {

    @IsTest
    static void testGetBookingLocationSettingsWithGoogleConnection() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Meet Event', 30);
            eventType.Location__c = '123 Main St';
            eventType.Video_Provider__c = 'Google_Meet';
            update eventType;

            SchedulingTestDataFactory.createCalendarConnection(testUser.Id, 'Google', true);

            Test.startTest();
            MeetingOptionsService.BookingLocationSettings settings =
                MeetingOptionsService.getBookingLocationSettings(testUser.Id, eventType.Id);
            Test.stopTest();

            System.assertEquals('123 Main St', settings.defaultLocation);
            System.assertNotEquals(null, settings.videoOptions);
        }
    }

    @IsTest
    static void testGetBookingLocationSettingsWithoutConnections() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Office Visit', 30);

            Test.startTest();
            MeetingOptionsService.BookingLocationSettings settings =
                MeetingOptionsService.getBookingLocationSettings(testUser.Id, eventType.Id);
            Test.stopTest();

            System.assertNotEquals(null, settings.videoOptions);
        }
    }
}
