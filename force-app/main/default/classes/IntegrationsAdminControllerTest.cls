@IsTest
private class IntegrationsAdminControllerTest {

    @IsTest
    static void getOverview_returnsStructuredData() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            insert new Calendar_Connection__c(
                Name = 'Google Calendar',
                Owner_User__c = testUser.Id,
                Provider__c = 'Google',
                Is_Active__c = true,
                Check_For_Conflicts__c = true,
                Push_Events_To__c = false
            );
            Test.startTest();
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();
            Test.stopTest();

            System.assertNotEquals(null, overview);
            System.assertEquals(10, overview.integrations.size());
            System.assertEquals(3, overview.permissionSets.size());
            System.assert(!overview.userSetups.isEmpty());
            System.assert(!overview.healthChecks.isEmpty());
            System.assertNotEquals(null, overview.orgDomainUrl);
        }
    }

    @IsTest
    static void getOverview_detectsPlaceholderAuthProviders() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();

            Boolean hasWarning = false;
            for (IntegrationsAdminController.HealthCheck hc : overview.healthChecks) {
                if (hc.title != null && hc.title.contains('OAuth app not configured')) {
                    hasWarning = true;
                }
            }
            System.assert(hasWarning, 'Expected auth provider configuration warnings');
        }
    }

    @IsTest
    static void getOverview_performsNoDml() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Integer dmlBefore = Limits.getDmlStatements();
            IntegrationsAdminController.getOverview();
            System.assertEquals(
                dmlBefore,
                Limits.getDmlStatements(),
                'getOverview must not perform DML'
            );
        }
    }

    @IsTest
    static void getOverview_permissionSetsIncludeHostAndAdmin() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();

            Map<String, IntegrationsAdminController.PermissionSetSummary> byName =
                new Map<String, IntegrationsAdminController.PermissionSetSummary>();
            for (IntegrationsAdminController.PermissionSetSummary ps : overview.permissionSets) {
                byName.put(ps.apiName, ps);
            }

            System.assert(byName.containsKey('Scheduling_Host'));
            System.assert(byName.containsKey('Scheduling_Admin'));
            System.assert(byName.containsKey('Scheduling_Booker'));
            System.assert(byName.get('Scheduling_Host').assignedCount >= 1);
            System.assert(byName.get('Scheduling_Admin').assignedCount >= 1);
        }
    }

    @IsTest
    static void getOverview_includesEmailDeliverabilitySummary() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();

            System.assertNotEquals(null, overview.emailDeliverability);
            System.assertNotEquals(null, overview.emailDeliverability.setupUrl);
            System.assertNotEquals(null, overview.emailDeliverability.deliverabilitySetupUrl);
            System.assertEquals('Cal.DIY Scheduling', overview.emailDeliverability.senderDisplayName);
            System.assert(overview.emailDeliverability.checklistItems.size() >= 5);

            Boolean hasEmailHealthCheck = false;
            for (IntegrationsAdminController.HealthCheck hc : overview.healthChecks) {
                if (hc.category == 'Email Deliverability') {
                    hasEmailHealthCheck = true;
                    System.assertNotEquals(null, hc.setupUrl);
                }
            }
            System.assert(hasEmailHealthCheck, 'Expected email deliverability health checks');
        }
    }

    @IsTest
    static void buildEmailDeliverabilitySummary_returnsChecklistAndUrls() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            String orgUrl = URL.getOrgDomainURL().toExternalForm();
            EmailDeliverabilityService.EmailDeliverabilitySummary summary =
                EmailDeliverabilityService.buildSummary(orgUrl);

            System.assertNotEquals(null, summary.status);
            System.assertNotEquals(null, summary.statusLabel);
            System.assert(summary.setupUrl.contains('OrgWideEmailAddresses'));
            System.assert(summary.deliverabilitySetupUrl.contains('Deliverability'));
            System.assertNotEquals(null, summary.isSandbox);
            System.assertEquals(summary.verifiedCount == 0, summary.substituteSenderOnly);
            System.assert(summary.checklistItems.size() >= 5);
        }
    }

    @IsTest
    static void getOverview_exercisesHealthCheckAndUserSetupBranches() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = SchedulingTestDataFactory.createSchedule(testUser.Id, 'Integrations Schedule', true);
            SchedulingTestDataFactory.createEventTypeWithSchedule(testUser.Id, schedule.Id, 'Integrations Event', 45);

            Calendar_Connection__c staleConnection = SchedulingTestDataFactory.createCalendarConnection(
                testUser.Id, 'Google', true
            );
            staleConnection.Last_Sync__c = Datetime.now().addDays(-3);
            update staleConnection;

            SchedulingTestDataFactory.createCalendarConnection(testUser.Id, 'Microsoft', false);

            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Health Check Event', 30);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id,
                testUser.Id,
                Datetime.now().addDays(10),
                Datetime.now().addDays(10).addMinutes(30)
            );
            booking.External_Event_Id__c = null;
            update booking;

            insert new Payment__c(
                Booking__c = booking.Id,
                Amount__c = 25,
                Currency_Code__c = 'USD',
                Status__c = 'Failed',
                External_Payment_Id__c = 'pi_failed_123',
                Provider__c = 'Stripe'
            );

            Test.startTest();
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();
            Test.stopTest();

            Boolean hasStaleSyncCheck = false;
            Boolean hasUnsyncedBookingCheck = false;
            Boolean hasFailedPaymentCheck = false;
            for (IntegrationsAdminController.HealthCheck hc : overview.healthChecks) {
                if (hc.title != null && hc.title.contains('Stale or never-synced')) {
                    hasStaleSyncCheck = true;
                }
                if (hc.title != null && hc.title.contains('without external calendar event')) {
                    hasUnsyncedBookingCheck = true;
                }
                if (hc.title != null && hc.title.contains('failed payments')) {
                    hasFailedPaymentCheck = true;
                }
            }

            System.assert(hasStaleSyncCheck);
            System.assert(hasUnsyncedBookingCheck);
            System.assert(hasFailedPaymentCheck);

            IntegrationsAdminController.UserSetupStatus hostRow;
            for (IntegrationsAdminController.UserSetupStatus row : overview.userSetups) {
                if (row.userId == testUser.Id) {
                    hostRow = row;
                }
            }
            System.assertNotEquals(null, hostRow);
            System.assert(hostRow.hasHostPermission);
            System.assert(hostRow.hasAdminPermission);
            System.assert(hostRow.hasCalendarConnection);
            System.assert(hostRow.scheduleCount >= 1);
            System.assert(hostRow.activeEventTypeCount >= 2);
            System.assert(hostRow.connections.size() >= 2);
        }
    }

    @IsTest
    static void getOverview_coversIntegrationStatusBranches() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            IntegrationsAdminController.IntegrationsOverview overview =
                IntegrationsAdminController.getOverview();

            Map<String, IntegrationsAdminController.IntegrationStatus> byKey =
                new Map<String, IntegrationsAdminController.IntegrationStatus>();
            for (IntegrationsAdminController.IntegrationStatus item : overview.integrations) {
                byKey.put(item.key, item);
            }

            System.assert(byKey.containsKey('Stripe'));
            System.assert(byKey.containsKey('GoogleMaps'));
            System.assert(byKey.containsKey('Twilio'));
            System.assert(byKey.containsKey('Zoom'));
            System.assert(byKey.containsKey('Google'));
            System.assert(byKey.containsKey('Microsoft'));
            System.assert(byKey.containsKey('Workday'));
            System.assertNotEquals(null, byKey.get('Stripe').detail);
            System.assertNotEquals(null, byKey.get('GoogleMaps').guidance);
            System.assertNotEquals(null, byKey.get('Google').authenticateUrl);
            System.assert(byKey.get('Google').guidance.contains('Named Principal'));
            System.assertNotEquals(null, overview.calendarSyncGuidance);
        }
    }

    @IsTest
    static void getOrgCalendarAuthStatus_returnsProviderResults() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> status = IntegrationsAdminController.getOrgCalendarAuthStatus();
            Test.stopTest();

            System.assert(status.containsKey('google'));
            System.assert(status.containsKey('microsoft'));
        }
    }
}
