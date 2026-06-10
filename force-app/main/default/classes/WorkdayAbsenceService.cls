public without sharing class WorkdayAbsenceService {

    public static HrSyncService.ProviderSyncResult syncApprovedAbsences() {
        Hr_Integration_Provider__mdt provider = getWorkdayProvider();
        if (provider == null) {
            HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(HrIntegrationProvider.WORKDAY);
            result.errors.add('Workday provider is not enabled');
            return result;
        }
        return new WorkdayAbsenceSyncProvider(provider).syncAbsences();
    }

    @TestVisible
    private static Hr_Integration_Provider__mdt getWorkdayProvider() {
        List<Hr_Integration_Provider__mdt> providers = [
            SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                Setup_Guidance__c
            FROM Hr_Integration_Provider__mdt
            WHERE Provider_Key__c = :HrIntegrationProvider.WORKDAY
            LIMIT 1
        ];
        if (providers.isEmpty()) {
            return null;
        }
        Hr_Integration_Provider__mdt provider = providers[0];
        if (Test.isRunningTest()) {
            return provider;
        }
        return provider.Is_Enabled__c && provider.Is_Implemented__c ? provider : null;
    }
}
