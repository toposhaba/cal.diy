public virtual class HrAbsenceSyncProvider {

    protected Hr_Integration_Provider__mdt config;

    protected HrAbsenceSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        config = providerConfig;
    }

    public virtual HrSyncService.ProviderSyncResult syncAbsences() {
        return new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
    }

    public virtual String getProviderKey() {
        return config != null ? config.Provider_Key__c : null;
    }
}
