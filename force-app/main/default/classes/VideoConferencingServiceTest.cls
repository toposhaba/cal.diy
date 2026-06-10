@IsTest
private class VideoConferencingServiceTest {

    @IsTest
    static void testCreateZoomMeeting() {
        User testUser = SchedulingTestDataFactory.createTestUser();
        ZoomTokenService.testAccessTokenOverride = 'zoom-s2s-token';
        ZoomTokenService.testDefaultUserId = 'host@example.com';

        System.runAs(testUser) {
            Booking__c booking = new Booking__c(
                Title__c = 'Zoom Meeting',
                Start_DateTime__c = Datetime.now().addDays(1),
                End_DateTime__c = Datetime.now().addDays(1).addMinutes(30)
            );

            Test.setMock(HttpCalloutMock.class, new ZoomCalloutMock());
            Test.startTest();
            String joinUrl = VideoConferencingService.createMeetingLink(booking, 'Zoom');
            Test.stopTest();

            System.assertEquals('https://zoom.example.com/join/123', joinUrl);
        }
    }

    private class ZoomCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('/users/'));
            System.assert(req.getEndpoint().contains('host%40example.com'));
            System.assertEquals('Bearer zoom-s2s-token', req.getHeader('Authorization'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"join_url":"https://zoom.example.com/join/123"}');
            return res;
        }
    }
}
