public with sharing class CalendarConnectionController {

    private static final Map<String, String> PROVIDER_NAMED_CREDENTIALS = new Map<String, String>{
        'Google' => 'Google_Calendar',
        'Microsoft' => 'Microsoft_Graph'
    };

    @AuraEnabled(cacheable=true)
    public static List<Calendar_Connection__c> getConnections() {
        return [
            SELECT Id, Name, Provider__c, Calendar_Id__c, Is_Active__c,
                   Check_For_Conflicts__c, Push_Events_To__c, Last_Sync__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            ORDER BY Provider__c ASC
        ];
    }

    @AuraEnabled
    public static Map<String, String> getNamedCredentialAuthUrl(String provider) {
        Map<String, String> result = new Map<String, String>();
        String namedCredential = PROVIDER_NAMED_CREDENTIALS.get(provider);

        if (namedCredential == null) {
            result.put('type', 'none');
            result.put('message', 'No OAuth required for ' + provider);
            return result;
        }

        String baseUrl = URL.getOrgDomainURL().toExternalForm();
        String authPageUrl = baseUrl + '/lightning/setup/NamedCredential/home';

        result.put('type', 'oauth');
        result.put('namedCredential', namedCredential);
        result.put('setupUrl', authPageUrl);
        result.put('provider', provider);
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> verifyConnection(String provider) {
        Map<String, Object> result = new Map<String, Object>();
        String namedCredential = PROVIDER_NAMED_CREDENTIALS.get(provider);

        if (namedCredential == null || provider == 'Salesforce') {
            result.put('authenticated', true);
            result.put('message', 'No external authentication needed');
            return result;
        }

        try {
            HttpRequest req = new HttpRequest();
            if (provider == 'Google') {
                req.setEndpoint('callout:Google_Calendar/calendars/primary');
                req.setMethod('GET');
            } else if (provider == 'Microsoft') {
                req.setEndpoint('callout:Microsoft_Graph/me/calendar');
                req.setMethod('GET');
            }
            req.setTimeout(10000);

            HttpResponse res = new Http().send(req);
            Integer statusCode = res.getStatusCode();

            if (statusCode == 200) {
                result.put('authenticated', true);
                result.put('message', 'Connected successfully');
            } else if (statusCode == 401 || statusCode == 403) {
                result.put('authenticated', false);
                result.put('message', 'Not authorized. Please complete the OAuth flow in Setup.');
            } else {
                result.put('authenticated', false);
                result.put('message', 'Connection check returned status: ' + statusCode);
            }
        } catch (Exception e) {
            result.put('authenticated', false);
            result.put('message', 'OAuth not configured or not authorized: ' + e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static Calendar_Connection__c createConnection(
        String provider, String calendarId, Boolean checkConflicts, Boolean pushEvents
    ) {
        if (String.isBlank(provider)) {
            AuraHandledException ex = new AuraHandledException('Provider is required');
            ex.setMessage('Provider is required');
            throw ex;
        }

        Calendar_Connection__c conn = new Calendar_Connection__c(
            Name = provider + ' Calendar',
            Owner_User__c = UserInfo.getUserId(),
            Provider__c = provider,
            Calendar_Id__c = calendarId,
            Is_Active__c = true,
            Check_For_Conflicts__c = checkConflicts,
            Push_Events_To__c = pushEvents
        );
        insert as user conn;
        return conn;
    }

    @AuraEnabled
    public static void toggleConnection(Id connectionId) {
        List<Calendar_Connection__c> connList = [
            SELECT Id, Is_Active__c
            FROM Calendar_Connection__c
            WHERE Id = :connectionId AND Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (connList.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Connection not found');
            ex.setMessage('Connection not found');
            throw ex;
        }
        Calendar_Connection__c conn = connList[0];

        conn.Is_Active__c = !conn.Is_Active__c;
        update as user conn;
    }

    @AuraEnabled
    public static void deleteConnection(Id connectionId) {
        List<Calendar_Connection__c> connList = [
            SELECT Id
            FROM Calendar_Connection__c
            WHERE Id = :connectionId AND Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (connList.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Connection not found');
            ex.setMessage('Connection not found');
            throw ex;
        }
        Calendar_Connection__c conn = connList[0];

        delete as user conn;
    }
}
