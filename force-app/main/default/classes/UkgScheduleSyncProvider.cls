public class UkgScheduleSyncProvider extends HrScheduleSyncProvider {
    public UkgScheduleSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }
    public override HrSyncService.ProviderSyncResult syncSchedules() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        result.errors.add('UKG schedule sync is not yet implemented');
        return result;
    }
}
