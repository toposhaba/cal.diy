public with sharing class CalendarIntegrationService {

    public static List<BusySlot> getExternalBusyTimes(Id userId, Datetime rangeStart, Datetime rangeEnd) {
        List<Calendar_Connection__c> connections = [
            SELECT Id, Provider__c, Calendar_Id__c, Check_For_Conflicts__c, Owner_User__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :userId
                AND Is_Active__c = true
                AND Check_For_Conflicts__c = true
            WITH USER_MODE
        ];

        List<BusySlot> allBusySlots = new List<BusySlot>();

        for (Calendar_Connection__c conn : connections) {
            try {
                List<BusySlot> providerSlots = fetchBusyTimes(conn, rangeStart, rangeEnd);
                allBusySlots.addAll(providerSlots);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to fetch busy times from ' + conn.Provider__c + ': ' + e.getMessage());
            }
        }

        return allBusySlots;
    }

    public static String createExternalEvent(Id bookingId) {
        List<Booking__c> bookingList = [
            SELECT Id, Title__c, Start_DateTime__c, End_DateTime__c, Location__c,
                   Booker_Email__c, Booker_Name__c, Host__c,
                   Event_Type__r.Description__c
            FROM Booking__c
            WHERE Id = :bookingId
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookingList.isEmpty()) {
            throw new SchedulingException('BOOKING_NOT_FOUND', 'Booking not found for calendar sync');
        }
        Booking__c booking = bookingList[0];

        List<Calendar_Connection__c> connections = [
            SELECT Id, Provider__c, Calendar_Id__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :booking.Host__c
                AND Is_Active__c = true
                AND Push_Events_To__c = true
            WITH USER_MODE
        ];

        String externalEventId;
        for (Calendar_Connection__c conn : connections) {
            try {
                externalEventId = pushEventToProvider(conn, booking);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to push event to ' + conn.Provider__c + ': ' + e.getMessage());
            }
        }

        if (String.isNotBlank(externalEventId)) {
            booking.External_Event_Id__c = externalEventId;
            update as user booking;
        }

        return externalEventId;
    }

    public static void deleteExternalEvent(Id bookingId) {
        List<Booking__c> bookingList = [
            SELECT Id, External_Event_Id__c, Host__c
            FROM Booking__c
            WHERE Id = :bookingId AND External_Event_Id__c != null
            WITH USER_MODE
            LIMIT 1
        ];

        if (bookingList.isEmpty()) return;
        Booking__c booking = bookingList[0];

        List<Calendar_Connection__c> connections = [
            SELECT Id, Provider__c, Calendar_Id__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :booking.Host__c
                AND Is_Active__c = true
                AND Push_Events_To__c = true
            WITH USER_MODE
        ];

        for (Calendar_Connection__c conn : connections) {
            try {
                deleteEventFromProvider(conn, booking.External_Event_Id__c);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to delete event from ' + conn.Provider__c + ': ' + e.getMessage());
            }
        }

        booking.External_Event_Id__c = null;
        update as user booking;
    }

    private static List<BusySlot> fetchBusyTimes(Calendar_Connection__c conn, Datetime rangeStart, Datetime rangeEnd) {
        switch on conn.Provider__c {
            when 'Google' {
                return fetchGoogleBusyTimes(conn, rangeStart, rangeEnd);
            }
            when 'Microsoft' {
                return fetchMicrosoftBusyTimes(conn, rangeStart, rangeEnd);
            }
            when 'Salesforce' {
                return fetchSalesforceBusyTimes(conn, rangeStart, rangeEnd);
            }
            when else {
                return new List<BusySlot>();
            }
        }
    }

    private static List<BusySlot> fetchGoogleBusyTimes(Calendar_Connection__c conn, Datetime rangeStart, Datetime rangeEnd) {
        String calendarId = String.isNotBlank(conn.Calendar_Id__c) ? conn.Calendar_Id__c : 'primary';
        String timeMin = rangeStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String timeMax = rangeEnd.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Calendar/calendars/' +
            EncodingUtil.urlEncode(calendarId, 'UTF-8') +
            '/events?timeMin=' + EncodingUtil.urlEncode(timeMin, 'UTF-8') +
            '&timeMax=' + EncodingUtil.urlEncode(timeMax, 'UTF-8') +
            '&singleEvents=true&orderBy=startTime');
        req.setMethod('GET');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new SchedulingException('GOOGLE_API_ERROR', 'Google Calendar API returned: ' + res.getStatusCode());
        }

        return parseGoogleEvents(res.getBody());
    }

    private static List<BusySlot> fetchMicrosoftBusyTimes(Calendar_Connection__c conn, Datetime rangeStart, Datetime rangeEnd) {
        String timeMin = rangeStart.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String timeMax = rangeEnd.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        String calendarPath = String.isNotBlank(conn.Calendar_Id__c)
            ? '/me/calendars/' + EncodingUtil.urlEncode(conn.Calendar_Id__c, 'UTF-8') + '/events'
            : '/me/calendar/events';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Microsoft_Graph' + calendarPath +
            '?$filter=start/dateTime ge \'' + timeMin + '\' and end/dateTime le \'' + timeMax + '\'' +
            '&$select=subject,start,end,showAs');
        req.setMethod('GET');
        req.setTimeout(10000);
        req.setHeader('Prefer', 'outlook.timezone="UTC"');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new SchedulingException('MICROSOFT_API_ERROR', 'Microsoft Graph API returned: ' + res.getStatusCode());
        }

        return parseMicrosoftEvents(res.getBody());
    }

    private static List<BusySlot> fetchSalesforceBusyTimes(Calendar_Connection__c conn, Datetime rangeStart, Datetime rangeEnd) {
        List<BusySlot> slots = new List<BusySlot>();
        List<Event> events = [
            SELECT Id, StartDateTime, EndDateTime, Subject
            FROM Event
            WHERE OwnerId = :conn.Owner_User__c
                AND StartDateTime < :rangeEnd
                AND EndDateTime > :rangeStart
            WITH USER_MODE
            ORDER BY StartDateTime ASC
        ];

        for (Event evt : events) {
            slots.add(new BusySlot(evt.StartDateTime, evt.EndDateTime, evt.Subject));
        }
        return slots;
    }

    private static String pushEventToProvider(Calendar_Connection__c conn, Booking__c booking) {
        switch on conn.Provider__c {
            when 'Google' {
                return pushToGoogleCalendar(conn, booking);
            }
            when 'Microsoft' {
                return pushToMicrosoftCalendar(conn, booking);
            }
            when 'Salesforce' {
                return pushToSalesforceEvents(booking);
            }
            when else {
                return null;
            }
        }
    }

    private static String pushToGoogleCalendar(Calendar_Connection__c conn, Booking__c booking) {
        String calendarId = String.isNotBlank(conn.Calendar_Id__c) ? conn.Calendar_Id__c : 'primary';

        Map<String, Object> eventBody = new Map<String, Object>{
            'summary' => booking.Title__c,
            'description' => booking.Event_Type__r.Description__c,
            'start' => new Map<String, Object>{
                'dateTime' => booking.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            },
            'end' => new Map<String, Object>{
                'dateTime' => booking.End_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            },
            'attendees' => new List<Object>{
                new Map<String, Object>{ 'email' => booking.Booker_Email__c }
            }
        };

        if (String.isNotBlank(booking.Location__c)) {
            eventBody.put('location', booking.Location__c);
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Calendar/calendars/' +
            EncodingUtil.urlEncode(calendarId, 'UTF-8') + '/events');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(eventBody));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new SchedulingException('GOOGLE_CREATE_ERROR', 'Failed to create Google Calendar event: ' + res.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) responseMap.get('id');
    }

    private static String pushToMicrosoftCalendar(Calendar_Connection__c conn, Booking__c booking) {
        String calendarPath = String.isNotBlank(conn.Calendar_Id__c)
            ? '/me/calendars/' + EncodingUtil.urlEncode(conn.Calendar_Id__c, 'UTF-8') + '/events'
            : '/me/calendar/events';

        Map<String, Object> eventBody = new Map<String, Object>{
            'subject' => booking.Title__c,
            'body' => new Map<String, Object>{
                'contentType' => 'text',
                'content' => booking.Event_Type__r.Description__c != null ? booking.Event_Type__r.Description__c : ''
            },
            'start' => new Map<String, Object>{
                'dateTime' => booking.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss'),
                'timeZone' => 'UTC'
            },
            'end' => new Map<String, Object>{
                'dateTime' => booking.End_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss'),
                'timeZone' => 'UTC'
            },
            'attendees' => new List<Object>{
                new Map<String, Object>{
                    'emailAddress' => new Map<String, Object>{
                        'address' => booking.Booker_Email__c,
                        'name' => booking.Booker_Name__c
                    },
                    'type' => 'required'
                }
            }
        };

        if (String.isNotBlank(booking.Location__c)) {
            eventBody.put('location', new Map<String, Object>{ 'displayName' => booking.Location__c });
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Microsoft_Graph' + calendarPath);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(eventBody));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 201) {
            throw new SchedulingException('MICROSOFT_CREATE_ERROR', 'Failed to create Outlook event: ' + res.getStatusCode());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) responseMap.get('id');
    }

    private static String pushToSalesforceEvents(Booking__c booking) {
        Event sfEvent = new Event(
            Subject = booking.Title__c,
            StartDateTime = booking.Start_DateTime__c,
            EndDateTime = booking.End_DateTime__c,
            Location = booking.Location__c,
            Description = booking.Event_Type__r.Description__c,
            OwnerId = booking.Host__c
        );
        insert as user sfEvent;
        return sfEvent.Id;
    }

    private static void deleteEventFromProvider(Calendar_Connection__c conn, String externalEventId) {
        switch on conn.Provider__c {
            when 'Google' {
                deleteGoogleEvent(conn, externalEventId);
            }
            when 'Microsoft' {
                deleteMicrosoftEvent(externalEventId);
            }
            when 'Salesforce' {
                deleteSalesforceEvent(externalEventId);
            }
        }
    }

    private static void deleteGoogleEvent(Calendar_Connection__c conn, String eventId) {
        String calendarId = String.isNotBlank(conn.Calendar_Id__c) ? conn.Calendar_Id__c : 'primary';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Calendar/calendars/' +
            EncodingUtil.urlEncode(calendarId, 'UTF-8') + '/events/' +
            EncodingUtil.urlEncode(eventId, 'UTF-8'));
        req.setMethod('DELETE');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 204 && res.getStatusCode() != 200) {
            throw new SchedulingException('GOOGLE_DELETE_ERROR', 'Failed to delete Google event: ' + res.getStatusCode());
        }
    }

    private static void deleteMicrosoftEvent(String eventId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Microsoft_Graph/me/events/' + EncodingUtil.urlEncode(eventId, 'UTF-8'));
        req.setMethod('DELETE');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 204) {
            throw new SchedulingException('MICROSOFT_DELETE_ERROR', 'Failed to delete Outlook event: ' + res.getStatusCode());
        }
    }

    private static void deleteSalesforceEvent(String eventId) {
        try {
            Event sfEvent = [SELECT Id FROM Event WHERE Id = :eventId WITH USER_MODE LIMIT 1];
            delete as user sfEvent;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Salesforce event not found for deletion: ' + eventId);
        }
    }

    private static List<BusySlot> parseGoogleEvents(String responseBody) {
        List<BusySlot> slots = new List<BusySlot>();
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> items = (List<Object>) response.get('items');

        if (items == null) return slots;

        for (Object item : items) {
            Map<String, Object> event = (Map<String, Object>) item;
            String status = (String) event.get('status');
            if (status == 'cancelled') continue;

            Map<String, Object> startObj = (Map<String, Object>) event.get('start');
            Map<String, Object> endObj = (Map<String, Object>) event.get('end');

            String startStr = (String) startObj.get('dateTime');
            String endStr = (String) endObj.get('dateTime');

            if (String.isNotBlank(startStr) && String.isNotBlank(endStr)) {
                Datetime startDt = parseIso8601(startStr);
                Datetime endDt = parseIso8601(endStr);
                String summary = (String) event.get('summary');
                slots.add(new BusySlot(startDt, endDt, summary));
            }
        }
        return slots;
    }

    private static List<BusySlot> parseMicrosoftEvents(String responseBody) {
        List<BusySlot> slots = new List<BusySlot>();
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> items = (List<Object>) response.get('value');

        if (items == null) return slots;

        for (Object item : items) {
            Map<String, Object> event = (Map<String, Object>) item;
            String showAs = (String) event.get('showAs');
            if (showAs == 'free') continue;

            Map<String, Object> startObj = (Map<String, Object>) event.get('start');
            Map<String, Object> endObj = (Map<String, Object>) event.get('end');

            String startStr = (String) startObj.get('dateTime');
            String endStr = (String) endObj.get('dateTime');

            if (String.isNotBlank(startStr) && String.isNotBlank(endStr)) {
                Datetime startDt = parseIso8601(startStr);
                Datetime endDt = parseIso8601(endStr);
                String subject = (String) event.get('subject');
                slots.add(new BusySlot(startDt, endDt, subject));
            }
        }
        return slots;
    }

    private static Datetime parseIso8601(String isoStr) {
        String cleaned = isoStr.replace('T', ' ');
        if (cleaned.contains('Z')) {
            cleaned = cleaned.replace('Z', '');
        }
        if (cleaned.contains('+')) {
            cleaned = cleaned.substringBefore('+');
        }
        if (cleaned.lastIndexOf('-') > cleaned.indexOf(' ')) {
            cleaned = cleaned.substringBeforeLast('-');
        }
        cleaned = cleaned.substringBefore('.');
        return Datetime.valueOfGmt(cleaned);
    }

    public class BusySlot {
        @AuraEnabled public Datetime startTime { get; set; }
        @AuraEnabled public Datetime endTime { get; set; }
        @AuraEnabled public String title { get; set; }

        public BusySlot(Datetime startTime, Datetime endTime, String title) {
            this.startTime = startTime;
            this.endTime = endTime;
            this.title = title;
        }
    }
}
