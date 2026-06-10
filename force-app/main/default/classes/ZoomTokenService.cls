public with sharing class ZoomTokenService {

    private static final String EXTERNAL_CREDENTIAL = 'Zoom_Credential';
    private static final String PRINCIPAL_NAME = 'Zoom_Principal';
    private static final String AUTH_PROVIDER_DEV_NAME = 'Zoom_Auth';
    private static final String TOKEN_CALLOUT = 'callout:Zoom_OAuth_Token';
    private static final String TOKEN_ENDPOINT = 'https://zoom.us/oauth/token';

    private static final Set<String> PLACEHOLDER_VALUES = new Set<String>{
        'CONFIGURE_IN_SETUP',
        'YOUR_CLIENT_ID',
        'CHANGEME',
        'PLACEHOLDER'
    };

    private static String cachedAccessToken;
    private static Long cachedExpiresAtMs;

    @TestVisible
    private static Boolean testExternalCredentialConfigured;
    @TestVisible
    private static Boolean testAuthProviderConfigured;
    @TestVisible
    private static String testAuthProviderClientId;
    @TestVisible
    private static String testAuthProviderClientSecret;
    @TestVisible
    private static String testDefaultUserId;
    @TestVisible
    private static String testAccessTokenOverride;

    public static String getAccessToken() {
        if (Test.isRunningTest() && String.isNotBlank(testAccessTokenOverride)) {
            return testAccessTokenOverride;
        }

        if (String.isNotBlank(cachedAccessToken) && cachedExpiresAtMs > System.now().getTime()) {
            return cachedAccessToken;
        }

        String accountId = getAccountId();
        if (String.isBlank(accountId)) {
            throw new SchedulingException('ZOOM_CONFIG', 'Zoom Account ID is not configured.');
        }

        HttpResponse res;
        if (hasExternalCredentialCredentials()) {
            res = requestTokenViaNamedCredential(accountId);
        } else {
            ClientCredentials creds = resolveAuthProviderCredentials();
            if (creds == null) {
                throw new SchedulingException(
                    'ZOOM_CONFIG',
                    'Zoom Client ID and Secret are not configured on External Credential or Zoom Auth Provider.'
                );
            }
            res = requestTokenDirect(accountId, creds.clientId, creds.clientSecret);
        }

        if (res.getStatusCode() != 200) {
            throw new SchedulingException('ZOOM_TOKEN_ERROR', 'Failed to obtain Zoom access token: ' + res.getStatusCode());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) body.get('access_token');
        Integer expiresIn = body.containsKey('expires_in') ? (Integer) body.get('expires_in') : 3600;
        Integer cacheSeconds = Math.min(Math.max(expiresIn - 300, 60), 3300);

        cachedAccessToken = accessToken;
        cachedExpiresAtMs = System.now().getTime() + (cacheSeconds * 1000L);
        return accessToken;
    }

    public static String getDefaultUserId() {
        if (Test.isRunningTest() && String.isNotBlank(testDefaultUserId)) {
            return testDefaultUserId;
        }
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Zoom_User_Id__c : null;
    }

    public static String getAccountId() {
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Zoom_Account_Id__c : null;
    }

    public static Boolean hasAccountId() {
        return String.isNotBlank(getAccountId());
    }

    public static Boolean hasClientCredentials() {
        return hasExternalCredentialCredentials() || hasAuthProviderCredentials();
    }

    public static Boolean hasExternalCredentialCredentials() {
        if (Test.isRunningTest()) {
            return testExternalCredentialConfigured == true;
        }

        try {
            ConnectApi.ExternalCredential externalCredential =
                ConnectApi.NamedCredentials.getExternalCredential(EXTERNAL_CREDENTIAL);
            if (externalCredential == null || externalCredential.principals == null) {
                return false;
            }

            for (ConnectApi.ExternalCredentialPrincipal principal : externalCredential.principals) {
                if (principal.principalName != PRINCIPAL_NAME) {
                    continue;
                }
                return principal.authenticationStatus == ConnectApi.CredentialAuthenticationStatus.Configured;
            }
        } catch (Exception e) {
            return false;
        }
        return false;
    }

    public static Boolean hasAuthProviderCredentials() {
        if (Test.isRunningTest()) {
            if (testAuthProviderConfigured == true) {
                return true;
            }
            return String.isNotBlank(testAuthProviderClientId) && String.isNotBlank(testAuthProviderClientSecret);
        }

        ClientCredentials creds = resolveAuthProviderCredentials();
        return creds != null;
    }

    public static String getCredentialSourceLabel() {
        if (hasExternalCredentialCredentials()) {
            return 'External Credential';
        }
        if (hasAuthProviderCredentials()) {
            return 'Zoom Auth Provider';
        }
        return null;
    }

    public static Boolean isCredentialsReady() {
        return hasAccountId() && hasClientCredentials();
    }

    public static Boolean isConfigured() {
        return isCredentialsReady() && String.isNotBlank(getDefaultUserId());
    }

    private static HttpResponse requestTokenViaNamedCredential(String accountId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_CALLOUT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=account_credentials&account_id=' + EncodingUtil.urlEncode(accountId, 'UTF-8'));
        req.setTimeout(10000);
        return new Http().send(req);
    }

    private static HttpResponse requestTokenDirect(String accountId, String clientId, String clientSecret) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader(
            'Authorization',
            'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(clientId + ':' + clientSecret))
        );
        req.setBody('grant_type=account_credentials&account_id=' + EncodingUtil.urlEncode(accountId, 'UTF-8'));
        req.setTimeout(10000);
        return new Http().send(req);
    }

    private static ClientCredentials resolveAuthProviderCredentials() {
        if (Test.isRunningTest()) {
            if (String.isNotBlank(testAuthProviderClientId) && String.isNotBlank(testAuthProviderClientSecret)) {
                ClientCredentials testCreds = new ClientCredentials();
                testCreds.clientId = testAuthProviderClientId;
                testCreds.clientSecret = testAuthProviderClientSecret;
                return testCreds;
            }
            if (testAuthProviderConfigured == true) {
                ClientCredentials testCreds = new ClientCredentials();
                testCreds.clientId = 'auth-provider-client-id';
                testCreds.clientSecret = 'auth-provider-client-secret';
                return testCreds;
            }
            return null;
        }

        List<AuthProvider> providers = [
            SELECT ConsumerKey, ConsumerSecret
            FROM AuthProvider
            WHERE DeveloperName = :AUTH_PROVIDER_DEV_NAME
            LIMIT 1
        ];
        if (providers.isEmpty()) {
            return null;
        }

        AuthProvider provider = providers[0];
        if (isPlaceholder(provider.ConsumerKey) || isPlaceholder(provider.ConsumerSecret)) {
            return null;
        }

        ClientCredentials creds = new ClientCredentials();
        creds.clientId = provider.ConsumerKey;
        creds.clientSecret = provider.ConsumerSecret;
        return creds;
    }

    private static Boolean isPlaceholder(String value) {
        return String.isBlank(value) || PLACEHOLDER_VALUES.contains(value.toUpperCase());
    }

    private class ClientCredentials {
        public String clientId;
        public String clientSecret;
    }
}
