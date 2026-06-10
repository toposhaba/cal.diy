public class SuccessFactorsScheduleSyncProvider extends HrScheduleSyncProvider {
    public SuccessFactorsScheduleSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }
    public override HrSyncService.ProviderSyncResult syncSchedules() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        result.errors.add('SuccessFactors schedule sync is not yet implemented');
        return result;
    }
}
