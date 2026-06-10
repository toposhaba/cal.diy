public with sharing class MeetingOptionsService {

    private static final Set<String> PLACEHOLDER_VALUES = new Set<String>{
        'CONFIGURE_IN_SETUP',
        'YOUR_CLIENT_ID',
        'CHANGEME',
        'PLACEHOLDER'
    };

    private static final Map<String, String> AUTH_PROVIDER_DEV_NAMES = new Map<String, String>{
        'Google' => 'Google_Calendar_Auth',
        'Microsoft' => 'Microsoft_Graph_Auth'
    };

    public class MeetingOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
    }

    public class BookingLocationSettings {
        @AuraEnabled public String googlePlacesApiKey { get; set; }
        @AuraEnabled public List<MeetingOption> videoOptions { get; set; }
        @AuraEnabled public String defaultVideoProvider { get; set; }
        @AuraEnabled public String defaultLocation { get; set; }
    }

    public static BookingLocationSettings getBookingLocationSettings(Id hostUserId, Id eventTypeId) {
        Id targetHost = hostUserId != null ? hostUserId : UserInfo.getUserId();
        BookingLocationSettings settings = new BookingLocationSettings();
        settings.videoOptions = new List<MeetingOption>();
        settings.googlePlacesApiKey = resolveGooglePlacesApiKey();

        Set<String> activeProviders = getActiveCalendarProviders(targetHost);
        Map<String, Boolean> authConfigured = getAuthProviderConfigured();

        if (activeProviders.contains('Google') && authConfigured.get('Google')) {
            settings.videoOptions.add(buildOption('Google_Meet', 'Google Meet'));
        }
        if (activeProviders.contains('Microsoft') && authConfigured.get('Microsoft')) {
            settings.videoOptions.add(buildOption('Microsoft_Teams', 'Microsoft Teams'));
        }
        if (ZoomTokenService.isCredentialsReady()) {
            settings.videoOptions.add(buildOption('Zoom', 'Zoom'));
        }

        if (eventTypeId != null) {
            List<Event_Type__c> eventTypes = [
                SELECT Location__c, Video_Provider__c
                FROM Event_Type__c
                WHERE Id = :eventTypeId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!eventTypes.isEmpty()) {
                Event_Type__c eventType = eventTypes[0];
                settings.defaultLocation = eventType.Location__c;
                String eventProvider = eventType.Video_Provider__c;
                if (String.isNotBlank(eventProvider) && eventProvider != 'None' && isProviderAvailable(eventProvider, settings.videoOptions)) {
                    settings.defaultVideoProvider = eventProvider;
                }
            }
        }

        return settings;
    }

    private static MeetingOption buildOption(String value, String label) {
        MeetingOption option = new MeetingOption();
        option.value = value;
        option.label = label;
        return option;
    }

    private static Boolean isProviderAvailable(String provider, List<MeetingOption> options) {
        for (MeetingOption option : options) {
            if (option.value == provider) {
                return true;
            }
        }
        return false;
    }

    private static String resolveGooglePlacesApiKey() {
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        if (settings == null || String.isBlank(settings.Google_Places_API_Key__c)) {
            return null;
        }
        String key = settings.Google_Places_API_Key__c.trim();
        if (isPlaceholder(key)) {
            return null;
        }
        return key;
    }

    private static Set<String> getActiveCalendarProviders(Id hostUserId) {
        Set<String> providers = new Set<String>();
        for (Calendar_Connection__c conn : [
            SELECT Provider__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :hostUserId AND Is_Active__c = true
            WITH USER_MODE
        ]) {
            if (String.isNotBlank(conn.Provider__c)) {
                providers.add(conn.Provider__c);
            }
        }
        return providers;
    }

    private static Map<String, Boolean> getAuthProviderConfigured() {
        Map<String, Boolean> result = new Map<String, Boolean>{
            'Google' => false,
            'Microsoft' => false
        };

        Map<String, AuthProvider> providersByDevName = new Map<String, AuthProvider>();
        for (AuthProvider ap : [
            SELECT DeveloperName, ConsumerKey, ConsumerSecret
            FROM AuthProvider
            WHERE DeveloperName IN :AUTH_PROVIDER_DEV_NAMES.values()
        ]) {
            providersByDevName.put(ap.DeveloperName, ap);
        }

        for (String provider : AUTH_PROVIDER_DEV_NAMES.keySet()) {
            AuthProvider ap = providersByDevName.get(AUTH_PROVIDER_DEV_NAMES.get(provider));
            result.put(provider, ap != null && !isPlaceholder(ap.ConsumerKey) && !isPlaceholder(ap.ConsumerSecret));
        }

        return result;
    }

    private static Boolean isPlaceholder(String value) {
        return String.isBlank(value) || PLACEHOLDER_VALUES.contains(value.toUpperCase());
    }
}
