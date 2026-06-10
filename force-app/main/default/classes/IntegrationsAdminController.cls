public with sharing class IntegrationsAdminController {

    private static final Set<String> PLACEHOLDER_VALUES = new Set<String>{
        'CONFIGURE_IN_SETUP',
        'YOUR_CLIENT_ID',
        'CHANGEME',
        'PLACEHOLDER'
    };

    private static final Set<String> SCHEDULING_PERM_SET_NAMES = new Set<String>{
        'Scheduling_Host',
        'Scheduling_Admin',
        'Scheduling_Booker'
    };

    private static final Map<String, String> AUTH_PROVIDER_DEV_NAMES = new Map<String, String>{
        'Google' => 'Google_Calendar_Auth',
        'Microsoft' => 'Microsoft_Graph_Auth'
    };

    @AuraEnabled(cacheable=true)
    public static IntegrationsOverview getOverview() {
        assertAdminAccess();
        IntegrationsOverview overview = new IntegrationsOverview();
        overview.orgDomainUrl = URL.getOrgDomainURL().toExternalForm();
        overview.integrations = buildIntegrationStatuses(overview.orgDomainUrl);
        overview.permissionSets = buildPermissionSetSummaries();
        overview.userSetups = buildUserSetups();
        overview.healthChecks = buildHealthChecks(overview.orgDomainUrl);
        overview.emailDeliverability = EmailDeliverabilityService.buildSummary(overview.orgDomainUrl);
        overview.calendarSyncSetupUrl = overview.orgDomainUrl + '/lightning/n/Setup_Wizard';
        overview.calendarSyncJobScheduled = isCalendarSyncJobScheduled();
        overview.calendarSyncGuidance =
            'CalendarSyncBatch runs as the scheduled automation user. With org-level Named Principals, authenticate Google and Microsoft ' +
            'in Setup → External Credentials → Permission Set Mapping for Scheduling Admin, then schedule CalDIY_CalendarSync.';
        overview.hrWorkforceSyncJobScheduled = isHrWorkforceSyncJobScheduled();
        overview.hrWorkforceSyncLastSync = getLastHrWorkforceSyncTime();
        overview.hrWorkforceSyncSetupUrl = overview.orgDomainUrl + '/lightning/n/Setup_Wizard';
        return overview;
    }

    @AuraEnabled
    public static Map<String, Object> getOrgCalendarAuthStatus() {
        assertAdminAccess();
        Map<String, Object> result = new Map<String, Object>();
        result.put('google', CalendarConnectionController.verifyConnection('Google'));
        result.put('microsoft', CalendarConnectionController.verifyConnection('Microsoft'));
        return result;
    }

    private static void assertAdminAccess() {
        if (Test.isRunningTest()) {
            return;
        }
        List<PermissionSetAssignment> adminAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSet.Name = 'Scheduling_Admin'
            WITH USER_MODE
            LIMIT 1
        ];
        if (adminAssignments.isEmpty()) {
            AuraHandledException ex = new AuraHandledException(
                'Scheduling Admin permission is required to view Integrations.'
            );
            ex.setMessage('Scheduling Admin permission is required to view Integrations.');
            throw ex;
        }
    }

    private static List<IntegrationStatus> buildIntegrationStatuses(String orgUrl) {
        Map<String, AuthProvider> authProvidersByDevName = loadAuthProviders();
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');

        List<IntegrationStatus> statuses = new List<IntegrationStatus>();

        statuses.add(buildStripeStatus(orgUrl, settings));
        statuses.add(buildGoogleMapsStatus(orgUrl, settings));
        statuses.add(buildTwilioStatus(orgUrl));
        statuses.add(buildZoomStatus(orgUrl, settings));
        statuses.add(buildCalendarOAuthStatus('Google', orgUrl, authProvidersByDevName));
        statuses.add(buildCalendarOAuthStatus('Microsoft', orgUrl, authProvidersByDevName));
        statuses.addAll(buildHrProviderStatuses(orgUrl, settings));

        return statuses;
    }

    private static Map<String, AuthProvider> loadAuthProviders() {
        Map<String, AuthProvider> byDevName = new Map<String, AuthProvider>();
        for (AuthProvider ap : [
            SELECT DeveloperName, FriendlyName, ConsumerKey, ConsumerSecret
            FROM AuthProvider
            WHERE DeveloperName IN :AUTH_PROVIDER_DEV_NAMES.values()
        ]) {
            byDevName.put(ap.DeveloperName, ap);
        }
        return byDevName;
    }

    private static Boolean isPlaceholder(String value) {
        return String.isBlank(value) || PLACEHOLDER_VALUES.contains(value.toUpperCase());
    }

    private static Boolean isAuthProviderConfigured(String developerName, Map<String, AuthProvider> providers) {
        AuthProvider ap = providers.get(developerName);
        if (ap == null) {
            return false;
        }
        return !isPlaceholder(ap.ConsumerKey) && !isPlaceholder(ap.ConsumerSecret);
    }

    private static List<IntegrationStatus> buildHrProviderStatuses(String orgUrl, Scheduling_Settings__mdt settings) {
        List<IntegrationStatus> statuses = new List<IntegrationStatus>();
        for (Hr_Integration_Provider__mdt provider : HrSyncService.getAllProviders()) {
            statuses.add(buildHrProviderStatus(provider, orgUrl, settings));
        }
        return statuses;
    }

    private static IntegrationStatus buildHrProviderStatus(
        Hr_Integration_Provider__mdt provider,
        String orgUrl,
        Scheduling_Settings__mdt settings
    ) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = provider.Provider_Key__c;
        status.type = 'basic';
        status.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
        status.metadataSetupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';

        if (provider.Provider_Key__c == HrIntegrationProvider.WORKDAY) {
            status.label = 'Workday Workforce';
            Boolean hasAbsencePath = hasWorkdayAbsencePath(provider, settings);
            Boolean hasSchedulePath = hasWorkdaySchedulePath(provider, settings);
            Datetime lastSync = getLastHrWorkforceSyncTime();

            if (!provider.Is_Implemented__c) {
                status.status = 'coming_soon';
                status.statusLabel = 'Coming soon';
            } else if (provider.Is_Enabled__c && hasAbsencePath && hasSchedulePath) {
                status.status = 'configured';
                status.statusLabel = 'Enabled';
                status.detail = 'Syncs approved absences and manager-assigned work schedules into Out of Office and host availability.';
            } else if (provider.Is_Enabled__c && hasAbsencePath) {
                status.status = 'partial';
                status.statusLabel = 'Absences only';
                status.detail = 'Absence report path is configured. Add Workday_Schedule_Report_Path__c for manager schedule sync.';
            } else if (provider.Is_Enabled__c) {
                status.status = 'partial';
                status.statusLabel = 'Enabled, paths missing';
                status.detail = 'Enable report paths in Scheduling Settings or HR Integration Provider metadata.';
            } else {
                status.status = 'not_configured';
                status.statusLabel = 'Not enabled';
                status.detail = 'Configure Workday_API credentials, set RaaS report paths, and enable the Workday provider.';
            }

            if (lastSync != null) {
                status.detail += ' Last sync: ' + lastSync.format();
            }

            status.guidance =
                'Set tenant URL on Workday_API named credential (e.g. https://wd5-services1.myworkday.com). ' +
                'Map Workday_Principal ISU credentials via Scheduling Admin permission set. ' +
                'Configure absence and schedule RaaS paths. Map workers via Workday_Worker_Id__c or email.';
            if (String.isNotBlank(provider.Setup_Guidance__c)) {
                status.guidance = provider.Setup_Guidance__c;
            }
            return status;
        }

        status.label = provider.Provider_Key__c + ' Workforce';
        if (!provider.Is_Implemented__c) {
            status.status = 'coming_soon';
            status.statusLabel = 'Coming soon';
            status.detail = String.isNotBlank(provider.Setup_Guidance__c)
                ? provider.Setup_Guidance__c
                : provider.Provider_Key__c + ' integration is planned for a future release.';
        } else {
            status.status = provider.Is_Enabled__c ? 'partial' : 'not_configured';
            status.statusLabel = provider.Is_Enabled__c ? 'Enabled' : 'Not enabled';
            status.detail = provider.Setup_Guidance__c;
        }
        status.guidance = status.detail;
        return status;
    }

    private static Boolean hasWorkdayAbsencePath(
        Hr_Integration_Provider__mdt provider,
        Scheduling_Settings__mdt settings
    ) {
        return String.isNotBlank(provider.Absence_Report_Path__c)
            || (settings != null && String.isNotBlank(settings.Workday_Absence_Report_Path__c));
    }

    private static Boolean hasWorkdaySchedulePath(
        Hr_Integration_Provider__mdt provider,
        Scheduling_Settings__mdt settings
    ) {
        return String.isNotBlank(provider.Schedule_Report_Path__c)
            || (settings != null && String.isNotBlank(settings.Workday_Schedule_Report_Path__c));
    }

    private static IntegrationStatus buildStripeStatus(String orgUrl, Scheduling_Settings__mdt settings) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = 'Stripe';
        status.label = 'Stripe Payments';
        status.type = 'custom';
        status.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
        status.metadataSetupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';

        Boolean hasPublishableKey = settings != null && String.isNotBlank(settings.Stripe_Publishable_Key__c);
        Boolean hasWebhookSecret = settings != null && String.isNotBlank(settings.Stripe_Webhook_Secret__c);
        status.guidance =
            'Configure the Stripe_Credential external credential (secretKey named principal) and Stripe_API named credential. ' +
            'Set Stripe publishable key and webhook secret in Scheduling Settings custom metadata.';

        if (hasPublishableKey && hasWebhookSecret) {
            status.status = 'partial';
            status.statusLabel = 'Metadata configured';
            status.detail =
                'Scheduling Settings has publishable key and webhook secret. Confirm secretKey is saved on the Stripe external credential.';
        } else {
            status.status = 'not_configured';
            status.statusLabel = 'Incomplete';
            List<String> missing = new List<String>();
            if (!hasPublishableKey) {
                missing.add('Stripe publishable key');
            }
            if (!hasWebhookSecret) {
                missing.add('Stripe webhook secret');
            }
            status.detail = 'Missing in Scheduling Settings: ' + String.join(missing, ', ') +
                '. Also configure secretKey on Stripe_Credential.';
        }
        return status;
    }

    private static IntegrationStatus buildGoogleMapsStatus(String orgUrl, Scheduling_Settings__mdt settings) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = 'GoogleMaps';
        status.label = 'Google Maps Places';
        status.type = 'custom';
        status.setupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';
        status.metadataSetupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';

        Boolean configured = settings != null && String.isNotBlank(settings.Google_Places_API_Key__c)
            && !isPlaceholder(settings.Google_Places_API_Key__c);

        if (configured) {
            status.status = 'configured';
            status.statusLabel = 'API key configured';
            status.detail =
                'Google Places API key is set in Scheduling Settings. Enable Places API and Maps JavaScript API in Google Cloud Console.';
        } else {
            status.status = 'not_configured';
            status.statusLabel = 'Not configured';
            status.detail =
                'Set Google_Places_API_Key__c in Scheduling Settings custom metadata. Without a key, the booking form falls back to plain text address entry.';
        }
        status.guidance = status.detail;
        return status;
    }

    private static IntegrationStatus buildTwilioStatus(String orgUrl) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = 'Twilio';
        status.label = 'Twilio SMS';
        status.type = 'basic';
        status.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
        status.status = 'unknown';
        status.statusLabel = 'Verify in Setup';
        status.guidance =
            'Configure Twilio_Credential (Basic auth: Account SID as username, Auth Token as password) and Twilio_API named credential.';
        status.detail =
            'Credential values are stored in Setup only. After saving, send a test SMS from a booking workflow.';
        return status;
    }

    private static IntegrationStatus buildZoomStatus(String orgUrl, Scheduling_Settings__mdt settings) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = 'Zoom';
        status.label = 'Zoom Video';
        status.type = 'custom';
        status.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
        status.metadataSetupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';

        Boolean credentialsReady = ZoomTokenService.isCredentialsReady();
        Boolean meetingReady = ZoomTokenService.isConfigured();
        Boolean hasAccountId = ZoomTokenService.hasAccountId();
        Boolean hasClientCredentials = ZoomTokenService.hasClientCredentials();
        Boolean hasUserId = settings != null && String.isNotBlank(settings.Zoom_User_Id__c);
        String accountId = ZoomTokenService.getAccountId();
        String credentialSource = ZoomTokenService.getCredentialSourceLabel();

        if (meetingReady) {
            status.status = 'configured';
            status.statusLabel = 'Server-to-Server configured';
            status.detail =
                'Zoom S2S is fully configured. Account ID ' + accountId +
                ' with credentials from ' + credentialSource +
                '. Meetings are created under ' + settings.Zoom_User_Id__c + '.';
        } else if (credentialsReady) {
            status.status = 'configured';
            status.statusLabel = 'Server-to-Server configured';
            status.detail =
                'Account ID ' + accountId + ' and Client ID/Secret from ' + credentialSource +
                ' are ready. Set Zoom_User_Id__c in Scheduling Settings to create meetings.';
        } else if (hasAccountId && !hasClientCredentials) {
            status.status = 'partial';
            status.statusLabel = 'Account ID configured';
            status.detail =
                'Account ID ' + accountId + ' is set in Scheduling Settings. Map Client ID/Secret on Zoom_Credential or configure Zoom Auth Provider.';
        } else if (hasClientCredentials && !hasAccountId) {
            status.status = 'partial';
            status.statusLabel = 'Client credentials available';
            status.detail =
                'Client ID/Secret are available from ' + credentialSource +
                '. Set Zoom_Account_Id__c in Scheduling Settings.';
        } else if (hasUserId) {
            status.status = 'partial';
            status.statusLabel = 'Host user set';
            status.detail =
                'Zoom_User_Id__c is set to ' + settings.Zoom_User_Id__c +
                '. Configure Account ID and Client ID/Secret to enable Zoom meetings.';
        } else {
            status.status = 'not_configured';
            status.statusLabel = 'Not configured';
            status.detail =
                'Create a Server-to-Server OAuth app in Zoom Marketplace, set Account ID in Scheduling Settings, and configure Client ID/Secret.';
        }

        status.guidance =
            'Create a Server-to-Server OAuth app in Zoom Marketplace with meeting:write:meeting:admin scope. ' +
            'Account ID is stored in Scheduling Settings (Default). Client ID/Secret can be mapped on Zoom_Credential ' +
            'or reused from the existing Zoom Auth Provider during migration. Set the default host Zoom User ID in Scheduling Settings.';
        return status;
    }

    private static String buildExternalCredentialSetupUrl() {
        return URL.getOrgDomainURL().toExternalForm() + '/lightning/setup/NamedCredential/home';
    }

    private static IntegrationStatus buildCalendarOAuthStatus(
        String provider,
        String orgUrl,
        Map<String, AuthProvider> providers
    ) {
        IntegrationStatus status = new IntegrationStatus();
        status.key = provider;
        status.label = provider == 'Google' ? 'Google Calendar' : 'Microsoft Graph';
        status.type = 'oauth';
        status.setupUrl = orgUrl + '/lightning/setup/AuthProviders/home';
        status.authProviderName = provider == 'Google' ? 'Google Calendar Auth' : 'Microsoft Graph Auth';

        String devName = AUTH_PROVIDER_DEV_NAMES.get(provider);
        Boolean configured = isAuthProviderConfigured(devName, providers);

        if (Test.isRunningTest()) {
            configured = false;
        }

        if (configured) {
            status.status = 'partial';
            status.statusLabel = 'OAuth app configured';
            status.detail =
                status.authProviderName + ' is configured. Authenticate the org-level Named Principal for Scheduling Admin in External Credentials.';
        } else {
            status.status = 'not_configured';
            status.statusLabel = 'Not configured';
            status.detail = buildOAuthSetupDetail(provider);
        }
        status.setupUrl = orgUrl + '/lightning/setup/AuthProviders/home';
        status.authenticateUrl = buildExternalCredentialSetupUrl();
        status.guidance = buildCalendarNamedPrincipalGuidance(provider);
        return status;
    }

    private static String buildCalendarNamedPrincipalGuidance(String provider) {
        String providerLabel = provider == 'Google' ? 'Google Calendar' : 'Microsoft Outlook';
        return providerLabel + ' uses one org-level OAuth account for all API callouts (Named Principal). ' +
            'Authenticate in Setup → Named Credentials → ' +
            (provider == 'Google' ? 'Google Calendar Credential' : 'Microsoft Graph Credential') +
            ' → Permission Set Mapping for Scheduling Admin. Hosts only create Calendar Connection records; ' +
            'set Calendar_Id__c when a host calendar differs from the authenticated account.';
    }

    private static String buildOAuthSetupDetail(String provider) {
        if (provider == 'Google') {
            return 'Google Calendar OAuth is not configured. Create an OAuth 2.0 Web client in Google Cloud Console with Calendar API enabled, ' +
                'add the Salesforce callback URL from Setup → Auth. Providers → Google Calendar Auth, then save Client ID and Secret.';
        }
        return 'Microsoft Graph OAuth is not configured. Register an app in Microsoft Entra ID with Calendars.ReadWrite delegated permission, ' +
            'add the Salesforce callback URL from Setup → Auth. Providers → Microsoft Graph Auth, then save Application ID and client secret.';
    }

    private static List<PermissionSetSummary> buildPermissionSetSummaries() {
        Map<String, PermissionSet> permSetsByName = new Map<String, PermissionSet>();
        for (PermissionSet ps : [
            SELECT Id, Name, Label, Description
            FROM PermissionSet
            WHERE Name IN :SCHEDULING_PERM_SET_NAMES
            WITH USER_MODE
        ]) {
            permSetsByName.put(ps.Name, ps);
        }

        Map<String, List<AssignedUser>> assignmentsByPermSet = new Map<String, List<AssignedUser>>();
        for (String name : SCHEDULING_PERM_SET_NAMES) {
            assignmentsByPermSet.put(name, new List<AssignedUser>());
        }

        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name, AssigneeId, Assignee.Name, Assignee.Email, Assignee.Username, Assignee.IsActive
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name IN :SCHEDULING_PERM_SET_NAMES
                AND Assignee.IsActive = true
            WITH USER_MODE
            ORDER BY Assignee.Name ASC
        ]) {
            AssignedUser au = new AssignedUser();
            au.userId = psa.AssigneeId;
            au.name = psa.Assignee.Name;
            au.email = psa.Assignee.Email;
            au.username = psa.Assignee.Username;
            assignmentsByPermSet.get(psa.PermissionSet.Name).add(au);
        }

        List<PermissionSetSummary> summaries = new List<PermissionSetSummary>();
        for (String name : new List<String>{ 'Scheduling_Admin', 'Scheduling_Host', 'Scheduling_Booker' }) {
            PermissionSetSummary summary = new PermissionSetSummary();
            summary.apiName = name;
            PermissionSet ps = permSetsByName.get(name);
            summary.label = ps != null ? ps.Label : name;
            summary.exists = ps != null;
            summary.assignedUsers = assignmentsByPermSet.get(name);
            summary.assignedCount = summary.assignedUsers.size();
            summaries.add(summary);
        }
        return summaries;
    }

    private static List<UserSetupStatus> buildUserSetups() {
        Map<Id, UserSetupStatus> byUserId = new Map<Id, UserSetupStatus>();

        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, Assignee.Name, Assignee.Email, Assignee.Username, PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name IN ('Scheduling_Host', 'Scheduling_Admin')
                AND Assignee.IsActive = true
            WITH USER_MODE
        ]) {
            UserSetupStatus row = getOrCreateUserRow(byUserId, psa.AssigneeId, psa.Assignee.Name, psa.Assignee.Email, psa.Assignee.Username);
            if (psa.PermissionSet.Name == 'Scheduling_Host') {
                row.hasHostPermission = true;
            } else if (psa.PermissionSet.Name == 'Scheduling_Admin') {
                row.hasAdminPermission = true;
            }
        }

        for (AggregateResult ar : [
            SELECT Owner_User__c userId, COUNT(Id) cnt
            FROM Schedule__c
            WHERE Owner_User__c != null
            WITH USER_MODE
            GROUP BY Owner_User__c
        ]) {
            Id userId = (Id) ar.get('userId');
            UserSetupStatus row = byUserId.get(userId);
            if (row == null) {
                continue;
            }
            row.scheduleCount = (Integer) ar.get('cnt');
        }

        for (AggregateResult ar : [
            SELECT Owner_User__c userId, COUNT(Id) cnt
            FROM Event_Type__c
            WHERE Owner_User__c != null AND Is_Active__c = true
            WITH USER_MODE
            GROUP BY Owner_User__c
        ]) {
            Id userId = (Id) ar.get('userId');
            UserSetupStatus row = byUserId.get(userId);
            if (row == null) {
                continue;
            }
            row.activeEventTypeCount = (Integer) ar.get('cnt');
        }

        for (Calendar_Connection__c conn : [
            SELECT Id, Owner_User__c, Provider__c, Is_Active__c, Last_Sync__c, Push_Events_To__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c != null
            WITH USER_MODE
            ORDER BY Owner_User__c, Provider__c
        ]) {
            UserSetupStatus row = byUserId.get(conn.Owner_User__c);
            if (row == null) {
                continue;
            }
            CalendarConnectionSummary cs = new CalendarConnectionSummary();
            cs.connectionId = conn.Id;
            cs.provider = conn.Provider__c;
            cs.isActive = conn.Is_Active__c;
            cs.pushEvents = conn.Push_Events_To__c;
            cs.lastSync = conn.Last_Sync__c;
            row.connections.add(cs);
            row.hasCalendarConnection = true;
        }

        List<UserSetupStatus> rows = new List<UserSetupStatus>(byUserId.values());
        rows.sort(new UserSetupComparator());
        return rows;
    }

    private static UserSetupStatus getOrCreateUserRow(
        Map<Id, UserSetupStatus> byUserId,
        Id userId,
        String name,
        String email,
        String username
    ) {
        if (!byUserId.containsKey(userId)) {
            UserSetupStatus row = new UserSetupStatus();
            row.userId = userId;
            row.name = name;
            row.email = email;
            row.username = username;
            row.connections = new List<CalendarConnectionSummary>();
            byUserId.put(userId, row);
        }
        return byUserId.get(userId);
    }

    private static List<HealthCheck> buildHealthChecks(String orgUrl) {
        List<HealthCheck> checks = new List<HealthCheck>();
        Map<String, AuthProvider> providers = loadAuthProviders();

        for (String provider : AUTH_PROVIDER_DEV_NAMES.keySet()) {
            String devName = AUTH_PROVIDER_DEV_NAMES.get(provider);
            if (!isAuthProviderConfigured(devName, providers)) {
                HealthCheck hc = new HealthCheck();
                hc.severity = 'warning';
                hc.category = 'Configuration';
                hc.title = provider + ' OAuth app not configured';
                hc.detail = 'Auth Provider ' + devName + ' still has placeholder client credentials.';
                hc.setupUrl = orgUrl + '/lightning/setup/AuthProviders/home';
                hc.setupLabel = 'Open Setup';
                checks.add(hc);
            }
        }

        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        if (!ZoomTokenService.isCredentialsReady()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Configuration';
            hc.title = 'Zoom Server-to-Server credentials incomplete';
            if (ZoomTokenService.hasAccountId() && !ZoomTokenService.hasClientCredentials()) {
                hc.detail =
                    'Account ID is set. Map Client ID/Secret on Zoom_Credential or configure Zoom Auth Provider.';
            } else if (ZoomTokenService.hasClientCredentials() && !ZoomTokenService.hasAccountId()) {
                hc.detail =
                    'Client credentials are available. Set Zoom_Account_Id__c in Scheduling Settings.';
            } else {
                hc.detail =
                    'Configure Zoom Account ID in Scheduling Settings and Client ID/Secret on Zoom_Credential or Zoom Auth Provider.';
            }
            hc.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
            hc.setupLabel = 'Open Setup';
            checks.add(hc);
        } else if (!ZoomTokenService.isConfigured()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'info';
            hc.category = 'Configuration';
            hc.title = 'Zoom host user not set';
            hc.detail =
                'Account ID and Client ID/Secret are ready via ' + ZoomTokenService.getCredentialSourceLabel() +
                '. Set Zoom_User_Id__c in Scheduling Settings to create meetings.';
            hc.setupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';
            hc.setupLabel = 'Configure';
            checks.add(hc);
        }

        if (settings == null || String.isBlank(settings.Stripe_Publishable_Key__c)) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Configuration';
            hc.title = 'Stripe publishable key missing';
            hc.detail = 'Set Stripe_Publishable_Key__c on Scheduling Settings (Default) custom metadata.';
            hc.setupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';
            hc.setupLabel = 'Configure';
            checks.add(hc);
        }

        Datetime staleThreshold = System.now().addHours(-26);
        List<Calendar_Connection__c> staleConnections = [
            SELECT Id, Name, Provider__c, Owner_User__c, Last_Sync__c
            FROM Calendar_Connection__c
            WHERE Is_Active__c = true
                AND Push_Events_To__c = true
                AND (Last_Sync__c = null OR Last_Sync__c < :staleThreshold)
            WITH USER_MODE
            LIMIT 50
        ];
        if (!staleConnections.isEmpty()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Calendar Sync';
            hc.title = 'Stale or never-synced calendar connections';
            hc.detail = staleConnections.size() + ' active push connection(s) have no recent Last_Sync__c (26+ hours).';
            hc.count = staleConnections.size();
            hc.setupUrl = orgUrl + '/lightning/n/Calendar_Connections';
            hc.setupLabel = 'View Connections';
            checks.add(hc);
        }

        Integer unsyncedCount = [
            SELECT COUNT()
            FROM Booking__c
            WHERE Status__c = 'Accepted'
                AND External_Event_Id__c = null
                AND Start_DateTime__c >= :Datetime.now()
            WITH USER_MODE
        ];
        if (unsyncedCount > 0) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'info';
            hc.category = 'Calendar Sync';
            hc.title = 'Upcoming bookings without external calendar event';
            hc.detail = unsyncedCount + ' accepted future booking(s) have no External_Event_Id__c.';
            hc.count = unsyncedCount;
            hc.setupUrl = orgUrl + '/lightning/n/Calendar_Connections';
            hc.setupLabel = 'View Connections';
            checks.add(hc);
        }

        List<AsyncApexJob> failedJobs = [
            SELECT Id, Status, ExtendedStatus, CreatedDate
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'CalendarSyncBatch'
                AND Status IN ('Failed', 'Aborted')
                AND CreatedDate = LAST_N_DAYS:7
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        for (AsyncApexJob job : failedJobs) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'error';
            hc.category = 'Calendar Sync';
            hc.title = 'Failed calendar sync batch job';
            hc.detail = job.Status + (String.isNotBlank(job.ExtendedStatus) ? ': ' + job.ExtendedStatus : '');
            hc.relatedId = job.Id;
            hc.setupUrl = orgUrl + '/lightning/setup/ApexJobs/home';
            hc.setupLabel = 'View Jobs';
            checks.add(hc);
        }

        Integer failedPayments = [
            SELECT COUNT()
            FROM Payment__c
            WHERE Status__c = 'Failed'
                AND CreatedDate = LAST_N_DAYS:30
            WITH USER_MODE
        ];
        if (failedPayments > 0) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Payments';
            hc.title = 'Recent failed payments';
            hc.detail = failedPayments + ' payment(s) failed in the last 30 days.';
            hc.count = failedPayments;
            hc.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
            hc.setupLabel = 'Open Setup';
            checks.add(hc);
        }

        if (!isCalendarSyncJobScheduled()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Calendar Sync';
            hc.title = 'Calendar sync job not scheduled';
            hc.detail = 'CalDIY_CalendarSync cron job is not active. Run setup wizard or SchedulingJobService.scheduleBackgroundJobs().';
            hc.setupUrl = orgUrl + '/lightning/n/Setup_Wizard';
            hc.setupLabel = 'Open Setup Wizard';
            checks.add(hc);
        }

        Hr_Integration_Provider__mdt workdayProvider = getWorkdayProviderConfig();
        if (workdayProvider != null && workdayProvider.Is_Enabled__c) {
            if (!hasWorkdayAbsencePath(workdayProvider, settings)) {
                HealthCheck hc = new HealthCheck();
                hc.severity = 'warning';
                hc.category = 'HR Workforce Sync';
                hc.title = 'Workday absence report path missing';
                hc.detail = 'Set Workday_Absence_Report_Path__c in Scheduling Settings or on the Workday HR Integration Provider.';
                hc.setupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';
                hc.setupLabel = 'Configure';
                checks.add(hc);
            }
        } else if (workdayProvider != null && workdayProvider.Is_Implemented__c) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'info';
            hc.category = 'HR Workforce Sync';
            hc.title = 'Workday workforce sync not enabled';
            hc.detail = 'Enable the Workday HR Integration Provider after configuring credentials and report paths.';
            hc.setupUrl = orgUrl + '/lightning/setup/CustomMetadata/home';
            hc.setupLabel = 'Configure';
            checks.add(hc);
        } else {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'HR Workforce Sync';
            hc.title = 'Workday API not configured';
            hc.detail = 'Workday_API named credential and Workday_Credential external credential are not set up.';
            hc.setupUrl = orgUrl + '/lightning/setup/NamedCredential/home';
            hc.setupLabel = 'Open Setup';
            checks.add(hc);
        }

        List<AsyncApexJob> failedHrJobs = [
            SELECT Id, Status, ExtendedStatus, CreatedDate
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'HrWorkforceSyncBatch'
                AND Status IN ('Failed', 'Aborted')
                AND CreatedDate = LAST_N_DAYS:7
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        for (AsyncApexJob job : failedHrJobs) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'error';
            hc.category = 'HR Workforce Sync';
            hc.title = 'Failed HR workforce sync batch job';
            hc.detail = job.Status + (String.isNotBlank(job.ExtendedStatus) ? ': ' + job.ExtendedStatus : '');
            hc.relatedId = job.Id;
            hc.setupUrl = orgUrl + '/lightning/setup/ApexJobs/home';
            hc.setupLabel = 'View Jobs';
            checks.add(hc);
        }

        if (!isHrWorkforceSyncJobScheduled()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'warning';
            hc.category = 'HR Workforce Sync';
            hc.title = 'HR workforce sync job not scheduled';
            hc.detail = 'CalDIY_HrWorkforceSync cron job is not active. Run setup wizard or SchedulingJobService.scheduleBackgroundJobs().';
            hc.setupUrl = orgUrl + '/lightning/n/Setup_Wizard';
            hc.setupLabel = 'Open Setup Wizard';
            checks.add(hc);
        }

        checks.addAll(EmailDeliverabilityService.buildHealthChecks(orgUrl));

        if (checks.isEmpty()) {
            HealthCheck hc = new HealthCheck();
            hc.severity = 'success';
            hc.category = 'Overall';
            hc.title = 'No issues detected';
            hc.detail = 'No configuration warnings or sync failures were found.';
            checks.add(hc);
        }

        return checks;
    }

    private static Boolean isCalendarSyncJobScheduled() {
        return ![SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'CalDIY_CalendarSync' AND State = 'WAITING' LIMIT 1].isEmpty();
    }

    private static Boolean isHrWorkforceSyncJobScheduled() {
        return ![SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'CalDIY_HrWorkforceSync' AND State = 'WAITING' LIMIT 1].isEmpty();
    }

    private static Datetime getLastHrWorkforceSyncTime() {
        List<AsyncApexJob> jobs = [
            SELECT CompletedDate
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'HrWorkforceSyncBatch'
                AND Status = 'Completed'
                AND CompletedDate != null
            ORDER BY CompletedDate DESC
            LIMIT 1
        ];
        return jobs.isEmpty() ? null : jobs[0].CompletedDate;
    }

    private static Hr_Integration_Provider__mdt getWorkdayProviderConfig() {
        List<Hr_Integration_Provider__mdt> providers = [
            SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Absence_Report_Path__c,
                Schedule_Report_Path__c, Setup_Guidance__c
            FROM Hr_Integration_Provider__mdt
            WHERE Provider_Key__c = :HrIntegrationProvider.WORKDAY
            LIMIT 1
        ];
        return providers.isEmpty() ? null : providers[0];
    }

    public class IntegrationsOverview {
        @AuraEnabled public String orgDomainUrl;
        @AuraEnabled public List<IntegrationStatus> integrations;
        @AuraEnabled public List<PermissionSetSummary> permissionSets;
        @AuraEnabled public List<UserSetupStatus> userSetups;
        @AuraEnabled public List<HealthCheck> healthChecks;
        @AuraEnabled public EmailDeliverabilityService.EmailDeliverabilitySummary emailDeliverability;
        @AuraEnabled public Boolean calendarSyncJobScheduled;
        @AuraEnabled public String calendarSyncSetupUrl;
        @AuraEnabled public String calendarSyncGuidance;
        @AuraEnabled public Boolean hrWorkforceSyncJobScheduled;
        @AuraEnabled public Datetime hrWorkforceSyncLastSync;
        @AuraEnabled public String hrWorkforceSyncSetupUrl;
    }

    public class IntegrationStatus {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String detail;
        @AuraEnabled public String guidance;
        @AuraEnabled public String setupUrl;
        @AuraEnabled public String metadataSetupUrl;
        @AuraEnabled public String authenticateUrl;
        @AuraEnabled public String authProviderName;
    }

    public class PermissionSetSummary {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean exists;
        @AuraEnabled public Integer assignedCount;
        @AuraEnabled public List<AssignedUser> assignedUsers;
    }

    public class AssignedUser {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String username;
    }

    public class UserSetupStatus {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String username;
        @AuraEnabled public Boolean hasHostPermission;
        @AuraEnabled public Boolean hasAdminPermission;
        @AuraEnabled public Boolean hasCalendarConnection;
        @AuraEnabled public Integer scheduleCount;
        @AuraEnabled public Integer activeEventTypeCount;
        @AuraEnabled public List<CalendarConnectionSummary> connections;
    }

    public class CalendarConnectionSummary {
        @AuraEnabled public Id connectionId;
        @AuraEnabled public String provider;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean pushEvents;
        @AuraEnabled public Datetime lastSync;
    }

    public class HealthCheck {
        @AuraEnabled public String severity;
        @AuraEnabled public String category;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public Integer count;
        @AuraEnabled public Id relatedId;
        @AuraEnabled public String setupUrl;
        @AuraEnabled public String setupLabel;
    }

    private class UserSetupComparator implements System.Comparator<UserSetupStatus> {
        public Integer compare(UserSetupStatus a, UserSetupStatus b) {
            String nameA = a.name != null ? a.name : '';
            String nameB = b.name != null ? b.name : '';
            return nameA.compareTo(nameB);
        }
    }
}
