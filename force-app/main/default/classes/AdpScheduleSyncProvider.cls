public class AdpScheduleSyncProvider extends HrScheduleSyncProvider {
    public AdpScheduleSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }
    public override HrSyncService.ProviderSyncResult syncSchedules() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        result.errors.add('ADP schedule sync is not yet implemented');
        return result;
    }
}
