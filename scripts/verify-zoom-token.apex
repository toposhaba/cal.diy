Map<String, Object> report = new Map<String, Object>();
report.put('runAsUserId', UserInfo.getUserId());
report.put('runAsUsername', UserInfo.getUserName());

Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
report.put('zoomAccountId', settings != null ? settings.Zoom_Account_Id__c : null);
report.put('zoomUserId', settings != null ? settings.Zoom_User_Id__c : null);
report.put('credentialsReady', ZoomTokenService.isCredentialsReady());
report.put('fullyConfigured', ZoomTokenService.isConfigured());
report.put('credentialSource', ZoomTokenService.getCredentialSourceLabel());
report.put('hasExternalCredential', ZoomTokenService.hasExternalCredentialCredentials());
report.put('hasAuthProvider', ZoomTokenService.hasAuthProviderCredentials());

Map<String, Object> tokenTest = new Map<String, Object>();
tokenTest.put('test', 'ZoomTokenService.getAccessToken()');
try {
    String token = ZoomTokenService.getAccessToken();
    tokenTest.put('pass', String.isNotBlank(token));
    tokenTest.put('tokenLength', token != null ? token.length() : 0);
    tokenTest.put('httpStatus', 200);
} catch (SchedulingException se) {
    tokenTest.put('pass', false);
    tokenTest.put('errorCode', se.getErrorCode());
    tokenTest.put('error', se.getMessage());
    if (se.getMessage() != null && se.getMessage().contains(':')) {
        tokenTest.put('httpStatus', se.getMessage().substringAfterLast(': ').trim());
    }
} catch (Exception e) {
    tokenTest.put('pass', false);
    tokenTest.put('error', e.getMessage());
}
report.put('tokenTest', tokenTest);

Map<String, Object> meetingTest = new Map<String, Object>();
meetingTest.put('test', 'VideoConferencingService.createZoomMeeting (dry run)');
if (String.isBlank(ZoomTokenService.getDefaultUserId())) {
    meetingTest.put('pass', false);
    meetingTest.put('skipped', true);
    meetingTest.put('reason', 'Zoom_User_Id__c is not set in Scheduling Settings');
} else {
    try {
        Booking__c testBooking = new Booking__c(
            Title__c = 'Cal.DIY Zoom S2S Test',
            Start_DateTime__c = System.now().addHours(2),
            End_DateTime__c = System.now().addHours(3)
        );
        String joinUrl = VideoConferencingService.createMeetingLink(testBooking, 'Zoom');
        meetingTest.put('pass', String.isNotBlank(joinUrl));
        meetingTest.put('joinUrl', joinUrl);
        meetingTest.put('httpStatus', 201);
    } catch (SchedulingException se) {
        meetingTest.put('pass', false);
        meetingTest.put('errorCode', se.getErrorCode());
        meetingTest.put('error', se.getMessage());
        if (se.getMessage() != null && se.getMessage().contains(':')) {
            meetingTest.put('httpStatus', se.getMessage().substringAfterLast(': ').trim());
        }
    } catch (Exception e) {
        meetingTest.put('pass', false);
        meetingTest.put('error', e.getMessage());
    }
}
report.put('meetingTest', meetingTest);

System.debug(JSON.serializePretty(report));
