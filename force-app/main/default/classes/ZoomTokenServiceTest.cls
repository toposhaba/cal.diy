@IsTest
private class ZoomTokenServiceTest {

    @IsTest
    static void getAccessToken_usesExternalCredentialCallout() {
        ZoomTokenService.testExternalCredentialConfigured = true;
        Test.setMock(HttpCalloutMock.class, new ExternalCredentialTokenMock());
        Test.startTest();
        String token = ZoomTokenService.getAccessToken();
        Test.stopTest();

        System.assertEquals('zoom-s2s-token', token);
    }

    @IsTest
    static void getAccessToken_fallsBackToAuthProvider() {
        ZoomTokenService.testAuthProviderClientId = 'auth-client-id';
        ZoomTokenService.testAuthProviderClientSecret = 'auth-client-secret';
        Test.setMock(HttpCalloutMock.class, new AuthProviderTokenMock());
        Test.startTest();
        String token = ZoomTokenService.getAccessToken();
        Test.stopTest();

        System.assertEquals('zoom-s2s-token', token);
    }

    @IsTest
    static void hasAccountId_usesMetadataFallback() {
        System.assertEquals(true, ZoomTokenService.hasAccountId());
        System.assertEquals('AknhOyhtQSm9tdP_EqHdNw', ZoomTokenService.getAccountId());
    }

    @IsTest
    static void isCredentialsReady_usesAuthProviderFallback() {
        System.assertEquals(true, ZoomTokenService.hasAccountId());
        System.assertEquals(false, ZoomTokenService.isCredentialsReady());

        ZoomTokenService.testAuthProviderConfigured = true;
        System.assertEquals(true, ZoomTokenService.hasAuthProviderCredentials());
        System.assertEquals(true, ZoomTokenService.isCredentialsReady());
        System.assertEquals('Zoom Auth Provider', ZoomTokenService.getCredentialSourceLabel());
    }

    @IsTest
    static void isConfigured_requiresHostUserId() {
        ZoomTokenService.testAuthProviderConfigured = true;
        System.assertEquals(true, ZoomTokenService.isCredentialsReady());
        System.assertEquals(false, ZoomTokenService.isConfigured());

        ZoomTokenService.testDefaultUserId = 'host@example.com';
        System.assertEquals(true, ZoomTokenService.isConfigured());
    }

    private class ExternalCredentialTokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('Zoom_OAuth_Token'));
            System.assert(req.getBody().contains('AknhOyhtQSm9tdP_EqHdNw'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"zoom-s2s-token","expires_in":3600}');
            return res;
        }
    }

    private class AuthProviderTokenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals(TOKEN_ENDPOINT, req.getEndpoint());
            System.assert(req.getHeader('Authorization').startsWith('Basic '));
            System.assert(req.getBody().contains('AknhOyhtQSm9tdP_EqHdNw'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"zoom-s2s-token","expires_in":3600}');
            return res;
        }

        private final String TOKEN_ENDPOINT = 'https://zoom.us/oauth/token';
    }
}
