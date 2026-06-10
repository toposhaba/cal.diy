public class SuccessFactorsAbsenceSyncProvider extends HrAbsenceSyncProvider {
    public SuccessFactorsAbsenceSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }
    public override HrSyncService.ProviderSyncResult syncAbsences() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        result.errors.add('SuccessFactors absence sync is not yet implemented');
        return result;
    }
}
