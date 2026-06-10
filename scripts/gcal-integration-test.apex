Map<String, Object> report = new Map<String, Object>();
report.put('runAsUserId', UserInfo.getUserId());
report.put('runAsUsername', UserInfo.getUserName());

List<PermissionSetAssignment> adminPs = [
    SELECT AssigneeId, Assignee.Username
    FROM PermissionSetAssignment
    WHERE PermissionSet.Name = 'Scheduling_Admin'
    LIMIT 5
];
report.put('schedulingAdminAssignments', adminPs.size());

User adminUser;
if (!adminPs.isEmpty()) {
    adminUser = [SELECT Id, Username FROM User WHERE Id = :adminPs[0].AssigneeId LIMIT 1];
} else {
    adminUser = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];
}

Map<String, Object> tests = new Map<String, Object>();

System.runAs(adminUser) {
    Map<String, Object> t1 = new Map<String, Object>();
    t1.put('test', 'CalendarConnectionController.verifyConnection(Google)');
    try {
        Map<String, Object> vr = CalendarConnectionController.verifyConnection('Google');
        t1.put('result', vr);
        t1.put('pass', vr.get('authenticated') == true);
    } catch (Exception e) {
        t1.put('pass', false);
        t1.put('error', e.getMessage());
    }
    tests.put('test1_verifyConnection', t1);

    Map<String, Object> t2 = new Map<String, Object>();
    t2.put('test', 'IntegrationsAdminController.getOrgCalendarAuthStatus');
    try {
        Map<String, Object> authStatus = IntegrationsAdminController.getOrgCalendarAuthStatus();
        t2.put('result', authStatus);
        Map<String, Object> googleStatus = (Map<String, Object>) authStatus.get('google');
        t2.put('pass', googleStatus != null && googleStatus.get('authenticated') == true);
    } catch (Exception e) {
        t2.put('pass', false);
        t2.put('error', e.getMessage());
    }
    tests.put('test2_orgCalendarAuthStatus', t2);
}

Map<String, Object> t3 = new Map<String, Object>();
t3.put('test', 'HTTP GET primary calendar (read-only)');
try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Google_Calendar/calendars/primary');
    req.setMethod('GET');
    req.setTimeout(12000);
    HttpResponse res = new Http().send(req);
    t3.put('httpStatus', res.getStatusCode());
    String body = res.getBody();
    t3.put('bodySnippet', body != null && body.length() > 500 ? body.substring(0, 500) : body);
    t3.put('pass', res.getStatusCode() == 200);
} catch (Exception e) {
    t3.put('pass', false);
    t3.put('error', e.getMessage());
}
tests.put('test3_primaryCalendarGet', t3);

Map<String, Object> t4 = new Map<String, Object>();
t4.put('test', 'HTTP GET calendarList (read-only)');
try {
    HttpRequest req2 = new HttpRequest();
    req2.setEndpoint('callout:Google_Calendar/users/me/calendarList?maxResults=5');
    req2.setMethod('GET');
    req2.setTimeout(12000);
    HttpResponse res2 = new Http().send(req2);
    t4.put('httpStatus', res2.getStatusCode());
    String body2 = res2.getBody();
    t4.put('bodySnippet', body2 != null && body2.length() > 500 ? body2.substring(0, 500) : body2);
    t4.put('pass', res2.getStatusCode() == 200);
} catch (Exception e) {
    t4.put('pass', false);
    t4.put('error', e.getMessage());
}
tests.put('test4_calendarList', t4);

Map<String, Object> t5 = new Map<String, Object>();
t5.put('test', 'CalendarIntegrationService.getExternalBusyTimes (read-only if connection exists)');
try {
    List<Calendar_Connection__c> conns = [
        SELECT Id, Owner_User__c, Provider__c, Is_Active__c, Check_For_Conflicts__c
        FROM Calendar_Connection__c
        WHERE Provider__c = 'Google' AND Is_Active__c = true
        LIMIT 1
    ];
    t5.put('googleConnectionsFound', conns.size());
    if (conns.isEmpty()) {
        t5.put('pass', null);
        t5.put('skipped', true);
        t5.put('message', 'No active Google Calendar_Connection__c; skipped service callout');
    } else {
        Datetime start = Datetime.now();
        Datetime endDt = start.addHours(24);
        List<CalendarIntegrationService.BusySlot> slots =
            CalendarIntegrationService.getExternalBusyTimes(conns[0].Owner_User__c, start, endDt);
        t5.put('busySlotCount', slots.size());
        t5.put('pass', true);
    }
} catch (Exception e) {
    t5.put('pass', false);
    t5.put('error', e.getMessage());
}
tests.put('test5_busyTimes', t5);

report.put('adminUserUsed', adminUser.Username);
report.put('tests', tests);
System.debug(LoggingLevel.ERROR, 'GCAL_INTEGRATION_REPORT_JSON_START');
System.debug(LoggingLevel.ERROR, JSON.serializePretty(report));
System.debug(LoggingLevel.ERROR, 'GCAL_INTEGRATION_REPORT_JSON_END');
