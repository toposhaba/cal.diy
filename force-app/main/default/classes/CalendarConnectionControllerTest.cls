@IsTest
private class CalendarConnectionControllerTest {

    @IsTest
    static void testCreateAndToggleConnection() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Calendar_Connection__c conn = CalendarConnectionController.createConnection(
                'Salesforce', 'primary', true, false
            );
            CalendarConnectionController.toggleConnection(conn.Id);
            Test.stopTest();

            Calendar_Connection__c updated = [
                SELECT Is_Active__c
                FROM Calendar_Connection__c
                WHERE Id = :conn.Id
            ];
            System.assertEquals(false, updated.Is_Active__c);
        }
    }

    @IsTest
    static void testGetConnectionsAndDelete() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = CalendarConnectionController.createConnection(
                'Salesforce', null, true, true
            );

            Test.startTest();
            List<Calendar_Connection__c> connections = CalendarConnectionController.getConnections();
            CalendarConnectionController.deleteConnection(conn.Id);
            Test.stopTest();

            System.assertEquals(1, connections.size());
            System.assertEquals(0, [SELECT COUNT() FROM Calendar_Connection__c WHERE Id = :conn.Id]);
        }
    }

    @IsTest
    static void testNamedCredentialAuthUrlForAdmin() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> google = CalendarConnectionController.getNamedCredentialAuthUrl('Google', 'Integrations');
            Map<String, Object> verify = CalendarConnectionController.verifyConnection('Salesforce');
            Test.stopTest();

            System.assertEquals(true, CalendarConnectionController.isSchedulingAdminUser());

            if (CalendarConnectionController.isAuthProviderConfigured('Google')) {
                System.assertEquals('admin_oauth', google.get('type'));
                System.assertNotEquals(null, google.get('authUrl'));
            } else {
                System.assertEquals('oauth_not_configured', google.get('type'));
                System.assert(google.get('message').contains('Google Cloud Console'));
            }
            System.assertEquals(true, verify.get('authenticated'));

            Map<String, String> microsoft = CalendarConnectionController.getNamedCredentialAuthUrl('Microsoft', 'Integrations');
            if (CalendarConnectionController.isAuthProviderConfigured('Microsoft')) {
                System.assertEquals('admin_oauth', microsoft.get('type'));
                System.assertNotEquals(null, microsoft.get('authUrl'));
            } else {
                System.assertEquals('oauth_not_configured', microsoft.get('type'));
                System.assert(microsoft.get('message').contains('Microsoft Entra ID'));
            }
        }
    }

    @IsTest
    static void testNamedCredentialAuthUrlForHostOnlyUser() {
        User hostUser = createHostOnlyUser();

        System.runAs(hostUser) {
            Test.startTest();
            Map<String, String> google = CalendarConnectionController.getNamedCredentialAuthUrl('Google', 'Setup_Wizard');
            Test.stopTest();

            System.assertEquals(false, CalendarConnectionController.isSchedulingAdminUser());
            if (CalendarConnectionController.isAuthProviderConfigured('Google')) {
                System.assertEquals('admin_required', google.get('type'));
                System.assert(google.get('message').contains('org level'));
            } else {
                System.assertEquals('oauth_not_configured', google.get('type'));
            }
        }
    }

    @IsTest
    static void testVerifyExternalProviderInTestContext() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> google = CalendarConnectionController.verifyConnection('Google');
            Map<String, Object> microsoft = CalendarConnectionController.verifyConnection('Microsoft');
            Test.stopTest();

            System.assertEquals(false, google.get('authenticated'));
            System.assertEquals(false, microsoft.get('authenticated'));
        }
    }

    @IsTest
    static void testPlaceholderDetection() {
        System.assertEquals(true, CalendarConnectionController.isPlaceholder(null));
        System.assertEquals(true, CalendarConnectionController.isPlaceholder(''));
        System.assertEquals(true, CalendarConnectionController.isPlaceholder('CONFIGURE_IN_SETUP'));
        System.assertEquals(true, CalendarConnectionController.isPlaceholder('Placeholder_Value'));
        System.assertEquals(true, CalendarConnectionController.isPlaceholder('YOUR_CLIENT_ID'));
        System.assertEquals(
            false,
            CalendarConnectionController.isPlaceholder('828047039582-abc.apps.googleusercontent.com')
        );
    }

    @IsTest
    static void testOAuthNotConfiguredMessages() {
        System.assert(
            CalendarConnectionController.buildOAuthNotConfiguredMessage('Google').contains('Google Cloud Console')
        );
        System.assert(
            CalendarConnectionController.buildOAuthNotConfiguredMessage('Microsoft').contains('Microsoft Entra ID')
        );
        System.assert(
            CalendarConnectionController.buildOAuthNotConfiguredMessage('Other').contains('not configured')
        );
        System.assert(
            CalendarConnectionController.buildAdminRequiredMessage('Google').contains('Scheduling Admin')
        );
        System.assert(
            CalendarConnectionController.buildOrgNotAuthenticatedMessage('Microsoft').contains('Named Principal')
        );
    }

    private static User createHostOnlyUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueStr = String.valueOf(Datetime.now().getTime()) + 'hostonly';
        User u = new User(
            FirstName = 'Host',
            LastName = 'Only',
            Email = 'hostonly' + uniqueStr + '@example.com',
            Username = 'hostonly' + uniqueStr + '@example.com.test',
            Alias = 'honly',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        PermissionSet hostPerm = [
            SELECT Id FROM PermissionSet WHERE Name = 'Scheduling_Host' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = hostPerm.Id
        );
        return u;
    }
}
