public virtual class HrScheduleSyncProvider {

    protected Hr_Integration_Provider__mdt config;

    protected HrScheduleSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        config = providerConfig;
    }

    public virtual HrSyncService.ProviderSyncResult syncSchedules() {
        return new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
    }

    public virtual String getProviderKey() {
        return config != null ? config.Provider_Key__c : null;
    }
}
