public with sharing class CalendarConnectionController {

    private static final Map<String, String> PROVIDER_NAMED_CREDENTIALS = new Map<String, String>{
        'Google' => 'Google_Calendar',
        'Microsoft' => 'Microsoft_Graph'
    };

    private static final Map<String, String> PROVIDER_EXTERNAL_CREDENTIALS = new Map<String, String>{
        'Google' => 'Google_Calendar_Credential',
        'Microsoft' => 'Microsoft_Graph_Credential'
    };

    private static final Map<String, String> PROVIDER_PRINCIPAL_NAMES = new Map<String, String>{
        'Google' => 'Google_Calendar_Principal',
        'Microsoft' => 'Microsoft_Graph_Principal'
    };

    private static final Map<String, String> PROVIDER_AUTH_PROVIDERS = new Map<String, String>{
        'Google' => 'Google Calendar Auth',
        'Microsoft' => 'Microsoft Graph Auth'
    };

    private static final Map<String, String> PROVIDER_AUTH_PROVIDER_DEV_NAMES = new Map<String, String>{
        'Google' => 'Google_Calendar_Auth',
        'Microsoft' => 'Microsoft_Graph_Auth'
    };

    private static final Set<String> PLACEHOLDER_VALUES = new Set<String>{
        'CONFIGURE_IN_SETUP',
        'YOUR_CLIENT_ID',
        'CHANGEME',
        'PLACEHOLDER',
        'PLACEHOLDER_VALUE'
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

    @AuraEnabled(cacheable=true)
    public static Boolean isSchedulingAdminUser() {
        return isSchedulingAdmin();
    }

    @AuraEnabled
    public static Map<String, String> getNamedCredentialAuthUrl(String provider, String returnPageApiName) {
        Map<String, String> result = new Map<String, String>();
        String externalCredential = PROVIDER_EXTERNAL_CREDENTIALS.get(provider);
        String orgUrl = URL.getOrgDomainURL().toExternalForm();
        String integrationsUrl = orgUrl + '/lightning/n/Integrations';
        String externalCredentialSetupUrl = buildExternalCredentialSetupUrl();

        if (externalCredential == null) {
            result.put('type', 'none');
            result.put('message', 'No OAuth required for ' + provider);
            return result;
        }

        if (!isAuthProviderConfigured(provider)) {
            result.put('type', 'oauth_not_configured');
            result.put('provider', provider);
            result.put('authProviderName', PROVIDER_AUTH_PROVIDERS.get(provider));
            result.put('setupUrl', orgUrl + '/lightning/setup/AuthProviders/home');
            result.put('integrationsUrl', integrationsUrl);
            result.put('message', buildOAuthNotConfiguredMessage(provider));
            return result;
        }

        if (!isSchedulingAdmin()) {
            result.put('type', 'admin_required');
            result.put('provider', provider);
            result.put('integrationsUrl', integrationsUrl);
            result.put('setupUrl', externalCredentialSetupUrl);
            result.put('message', buildAdminRequiredMessage(provider));
            return result;
        }

        if (Test.isRunningTest()) {
            result.put('type', 'admin_oauth');
            result.put('authUrl', 'https://example.com/oauth');
            result.put('provider', provider);
            result.put('setupUrl', externalCredentialSetupUrl);
            result.put('integrationsUrl', integrationsUrl);
            return result;
        }

        try {
            ConnectApi.OAuthCredentialAuthUrlInput input = new ConnectApi.OAuthCredentialAuthUrlInput();
            input.externalCredential = externalCredential;
            input.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
            input.principalName = PROVIDER_PRINCIPAL_NAMES.get(provider);
            input.returnUrl = integrationsUrl;

            ConnectApi.OAuthCredentialAuthUrl output =
                ConnectApi.NamedCredentials.getOAuthCredentialAuthUrl(input);

            result.put('type', 'admin_oauth');
            result.put('authUrl', output.authenticationUrl);
            result.put('provider', provider);
            result.put('setupUrl', externalCredentialSetupUrl);
            result.put('integrationsUrl', integrationsUrl);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(
                'Unable to generate OAuth URL: ' + e.getMessage()
            );
            ex.setMessage('Unable to generate OAuth URL: ' + e.getMessage());
            throw ex;
        }

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

        if (Test.isRunningTest()) {
            result.put('authenticated', false);
            result.put('message', 'Org calendar integration is not authenticated in test context.');
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
                result.put('message', 'Org calendar integration is authenticated.');
            } else if (statusCode == 401 || statusCode == 403) {
                result.put('authenticated', false);
                result.put('message', buildOrgNotAuthenticatedMessage(provider));
            } else {
                result.put('authenticated', false);
                result.put('message', 'Connection check returned status: ' + statusCode);
            }
        } catch (Exception e) {
            result.put('authenticated', false);
            result.put('message', buildOrgNotAuthenticatedMessage(provider));
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

    @TestVisible
    private static Boolean isSchedulingAdmin() {
        List<PermissionSetAssignment> adminAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSet.Name = 'Scheduling_Admin'
            WITH USER_MODE
            LIMIT 1
        ];
        return !adminAssignments.isEmpty();
    }

    @TestVisible
    private static Boolean isAuthProviderConfigured(String provider) {
        String developerName = PROVIDER_AUTH_PROVIDER_DEV_NAMES.get(provider);
        if (developerName == null) {
            return false;
        }

        List<AuthProvider> providers = [
            SELECT ConsumerKey, ConsumerSecret
            FROM AuthProvider
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        if (providers.isEmpty()) {
            return false;
        }

        AuthProvider ap = providers[0];
        return !isPlaceholder(ap.ConsumerKey) && !isPlaceholder(ap.ConsumerSecret);
    }

    @TestVisible
    private static Boolean isPlaceholder(String value) {
        return String.isBlank(value) || PLACEHOLDER_VALUES.contains(value.toUpperCase());
    }

    @TestVisible
    private static String buildExternalCredentialSetupUrl() {
        return URL.getOrgDomainURL().toExternalForm() + '/lightning/setup/NamedCredential/home';
    }

    @TestVisible
    private static String buildAdminRequiredMessage(String provider) {
        String providerLabel = provider == 'Google' ? 'Google Calendar' : 'Microsoft Outlook';
        return providerLabel + ' is authenticated once at the org level by a Scheduling Admin. ' +
            'Open Integrations to complete setup, then add your calendar connection here.';
    }

    @TestVisible
    private static String buildOrgNotAuthenticatedMessage(String provider) {
        String providerLabel = provider == 'Google' ? 'Google Calendar' : 'Microsoft Outlook';
        return providerLabel + ' is not authenticated at the org level. A Scheduling Admin must authenticate ' +
            'the Named Principal in Integrations or Setup → External Credentials → Permission Set Mapping.';
    }

    @TestVisible
    private static String buildOAuthNotConfiguredMessage(String provider) {
        String authProviderName = PROVIDER_AUTH_PROVIDERS.get(provider);
        if (provider == 'Google') {
            return 'Google Calendar OAuth is not configured. In Google Cloud Console, create an OAuth 2.0 Web client ' +
                'with the Google Calendar API enabled and add the Salesforce callback URL from Setup → Auth. Providers → ' +
                authProviderName + '. Then paste the Client ID and Client Secret into that Auth Provider before authenticating the org-level principal.';
        }
        if (provider == 'Microsoft') {
            return 'Microsoft Graph OAuth is not configured. In Microsoft Entra ID, register an app with the ' +
                'Microsoft Graph Calendars.ReadWrite delegated permission and add the Salesforce callback URL from ' +
                'Setup → Auth. Providers → ' + authProviderName + '. Then paste the Application (client) ID and ' +
                'client secret into that Auth Provider before authenticating the org-level principal.';
        }
        return authProviderName + ' OAuth is not configured. Ask your Salesforce administrator to configure the ' +
            'Auth Provider in Setup before authenticating.';
    }
}
