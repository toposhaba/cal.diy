@IsTest
private class BookingRestApiTest {

    @IsTest
    static void testGetEventTypes() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            SchedulingTestDataFactory.createEventType(testUser.Id, 'REST Event', 30);

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/event-types';
            req.httpMethod = 'GET';
            req.params.put('hostUserId', testUser.Id);
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            String body = RestContext.response.responseBody.toString();
            System.assert(body.contains('REST Event'));
        }
    }

    @IsTest
    static void testGetEventTypesMissingParam() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/event-types';
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            Test.stopTest();

            System.assertEquals(400, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testGetSlots() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'API Slots', 30
            );

            Date futureDate = Date.today().addDays(7);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/slots';
            req.httpMethod = 'GET';
            req.params.put('eventTypeId', eventType.Id);
            req.params.put('startDate', String.valueOf(futureDate));
            req.params.put('endDate', String.valueOf(futureDate));
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testGetBookingByUid() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Test', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );

            Booking__c fetchedBooking = [SELECT UID__c FROM Booking__c WHERE Id = :booking.Id];

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/bookings/' + fetchedBooking.UID__c;
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
            String body = RestContext.response.responseBody.toString();
            System.assert(body.contains(fetchedBooking.UID__c));
        }
    }

    @IsTest
    static void testCreateBookingViaRest() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'API Booking', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));

            Map<String, Object> bodyMap = new Map<String, Object>{
                'eventTypeId' => eventType.Id,
                'startDateTime' => startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                'bookerEmail' => 'api@example.com',
                'bookerName' => 'API Booker',
                'attendeeEmails' => new List<String>()
            };

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/bookings';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serialize(bodyMap));
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doPost();
            Test.stopTest();

            System.assertEquals(201, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testPatchReschedule() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Work', true);
            SchedulingTestDataFactory.createWorkingHours(
                schedule.Id, 'Monday;Tuesday;Wednesday;Thursday;Friday',
                Time.newInstance(9, 0, 0, 0), Time.newInstance(17, 0, 0, 0)
            );
            Event_Type__c eventType = SchedulingTestDataFactory.createEventTypeWithSchedule(
                testUser.Id, schedule.Id, 'Reschedule API', 30
            );

            Date futureDate = Date.today().addDays(14);
            while (isWeekend(futureDate)) {
                futureDate = futureDate.addDays(1);
            }
            Datetime startDt = Datetime.newInstance(futureDate, Time.newInstance(10, 0, 0, 0));
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Booking__c fetchedBooking = [SELECT UID__c FROM Booking__c WHERE Id = :booking.Id];

            Datetime newStart = Datetime.newInstance(futureDate, Time.newInstance(14, 0, 0, 0));
            Map<String, Object> bodyMap = new Map<String, Object>{
                'startDateTime' => newStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            };

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/bookings/' + fetchedBooking.UID__c + '/reschedule';
            req.httpMethod = 'PATCH';
            req.requestBody = Blob.valueOf(JSON.serialize(bodyMap));
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doPatch();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testGetRoutingFormsAndEvaluate() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Routed', 30);
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'API Router');
            Routing_Form_Field__c field = SchedulingTestDataFactory.createRoutingFormField(
                form.Id, 'Topic', 'Select', 'Sales'
            );
            SchedulingTestDataFactory.createRoutingFormRoute(
                form.Id, eventType.Id,
                '{"fieldId":"' + field.Id + '","operator":"equals","value":"Sales"}'
            );

            RestRequest listReq = new RestRequest();
            listReq.requestURI = '/services/apexrest/scheduling/v1/routing-forms';
            listReq.httpMethod = 'GET';
            listReq.params.put('hostUserId', testUser.Id);
            RestContext.request = listReq;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            System.assertEquals(200, RestContext.response.statusCode);

            RestRequest fieldsReq = new RestRequest();
            fieldsReq.requestURI = '/services/apexrest/scheduling/v1/routing-forms/' + form.Id + '/fields';
            fieldsReq.httpMethod = 'GET';
            RestContext.request = fieldsReq;
            RestContext.response = new RestResponse();
            BookingRestApi.doGet();
            System.assertEquals(200, RestContext.response.statusCode);

            Map<String, Object> body = new Map<String, Object>{
                'fieldResponses' => new Map<String, String>{ field.Id => 'Sales' }
            };
            RestRequest evalReq = new RestRequest();
            evalReq.requestURI = '/services/apexrest/scheduling/v1/routing-forms/' + form.Id + '/evaluate';
            evalReq.httpMethod = 'POST';
            evalReq.requestBody = Blob.valueOf(JSON.serialize(body));
            RestContext.request = evalReq;
            RestContext.response = new RestResponse();
            BookingRestApi.doPost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testCancelBookingViaRest() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cancel API', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(5), Datetime.now().addDays(5).addMinutes(30)
            );
            Booking__c fetched = [SELECT UID__c FROM Booking__c WHERE Id = :booking.Id];

            Test.setMock(HttpCalloutMock.class, new RestWebhookMock());

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/bookings/' + fetched.UID__c + '/cancel';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf('{"reason":"Changed plans"}');
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doPost();
            Test.stopTest();

            System.assertEquals(200, RestContext.response.statusCode);
        }
    }

    @IsTest
    static void testNotFoundEndpoint() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/scheduling/v1/nonexistent';
            req.httpMethod = 'GET';
            RestContext.request = req;
            RestContext.response = new RestResponse();

            Test.startTest();
            BookingRestApi.doGet();
            Test.stopTest();

            System.assertEquals(404, RestContext.response.statusCode);
        }
    }

    private static Boolean isWeekend(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        String dayName = dt.format('EEEE');
        return dayName == 'Saturday' || dayName == 'Sunday';
    }

    private class RestWebhookMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
