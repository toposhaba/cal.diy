public with sharing class VideoConferencingService {

    public static String createMeetingLink(Booking__c booking, String provider) {
        switch on provider {
            when 'Zoom' {
                return createZoomMeeting(booking);
            }
            when 'Google_Meet' {
                return createGoogleMeet(booking);
            }
            when 'Microsoft_Teams' {
                return createTeamsMeeting(booking);
            }
            when else {
                return null;
            }
        }
    }

    private static String createZoomMeeting(Booking__c booking) {
        String zoomUserId = ZoomTokenService.getDefaultUserId();
        if (String.isBlank(zoomUserId)) {
            throw new SchedulingException('ZOOM_CONFIG', 'Zoom_User_Id__c is not configured in Scheduling Settings');
        }

        Map<String, Object> meetingBody = new Map<String, Object>{
            'topic' => booking.Title__c,
            'type' => 2,
            'start_time' => booking.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'duration' => getDurationMinutes(booking),
            'settings' => new Map<String, Object>{
                'join_before_host' => true,
                'waiting_room' => false
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:Zoom_API/users/' + EncodingUtil.urlEncode(zoomUserId, 'UTF-8') + '/meetings'
        );
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + ZoomTokenService.getAccessToken());
        req.setBody(JSON.serialize(meetingBody));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 201) {
            throw new SchedulingException('ZOOM_ERROR', 'Failed to create Zoom meeting: ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) response.get('join_url');
    }

    private static String createGoogleMeet(Booking__c booking) {
        Map<String, Object> eventBody = new Map<String, Object>{
            'summary' => booking.Title__c,
            'start' => new Map<String, Object>{
                'dateTime' => booking.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            },
            'end' => new Map<String, Object>{
                'dateTime' => booking.End_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
            },
            'conferenceData' => new Map<String, Object>{
                'createRequest' => new Map<String, Object>{
                    'requestId' => booking.Id,
                    'conferenceSolutionKey' => new Map<String, Object>{
                        'type' => 'hangoutsMeet'
                    }
                }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_Calendar/calendars/primary/events?conferenceDataVersion=1');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(eventBody));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new SchedulingException('GOOGLE_MEET_ERROR', 'Failed to create Google Meet: ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> conferenceData = (Map<String, Object>) response.get('conferenceData');
        if (conferenceData != null) {
            List<Object> entryPoints = (List<Object>) conferenceData.get('entryPoints');
            if (entryPoints != null && !entryPoints.isEmpty()) {
                Map<String, Object> ep = (Map<String, Object>) entryPoints[0];
                return (String) ep.get('uri');
            }
        }
        return null;
    }

    private static String createTeamsMeeting(Booking__c booking) {
        Map<String, Object> meetingBody = new Map<String, Object>{
            'subject' => booking.Title__c,
            'startDateTime' => booking.Start_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'endDateTime' => booking.End_DateTime__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'isOnlineMeeting' => true,
            'onlineMeetingProvider' => 'teamsForBusiness'
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Microsoft_Graph/me/events');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(meetingBody));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 201) {
            throw new SchedulingException('TEAMS_ERROR', 'Failed to create Teams meeting: ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> onlineMeeting = (Map<String, Object>) response.get('onlineMeeting');
        if (onlineMeeting != null) {
            return (String) onlineMeeting.get('joinUrl');
        }
        return null;
    }

    private static Integer getDurationMinutes(Booking__c booking) {
        if (booking.Start_DateTime__c == null || booking.End_DateTime__c == null) return 30;
        Long diffMs = booking.End_DateTime__c.getTime() - booking.Start_DateTime__c.getTime();
        return (Integer)(diffMs / 60000);
    }
}
