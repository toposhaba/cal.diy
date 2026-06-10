public class AdpAbsenceSyncProvider extends HrAbsenceSyncProvider {
    public AdpAbsenceSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }
    public override HrSyncService.ProviderSyncResult syncAbsences() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        result.errors.add('ADP absence sync is not yet implemented');
        return result;
    }
}
