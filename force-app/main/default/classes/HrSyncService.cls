public without sharing class HrSyncService {

    public static HrSyncResult syncAll() {
        HrSyncResult result = new HrSyncResult();
        for (Hr_Integration_Provider__mdt provider : getEnabledProviders()) {
            try {
                HrAbsenceSyncProvider absenceProvider = createAbsenceProvider(provider);
                if (absenceProvider != null) {
                    result.absenceResults.add(absenceProvider.syncAbsences());
                }
                HrScheduleSyncProvider scheduleProvider = createScheduleProvider(provider);
                if (scheduleProvider != null) {
                    result.scheduleResults.add(scheduleProvider.syncSchedules());
                }
            } catch (Exception e) {
                ProviderSyncResult errorResult = new ProviderSyncResult(provider.Provider_Key__c);
                errorResult.errors.add(e.getMessage());
                result.absenceResults.add(errorResult);
            }
        }
        return result;
    }

    public static List<Hr_Integration_Provider__mdt> getEnabledProviders() {
        return [
            SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                Setup_Guidance__c
            FROM Hr_Integration_Provider__mdt
            WHERE Is_Enabled__c = true AND Is_Implemented__c = true
        ];
    }

    public static List<Hr_Integration_Provider__mdt> getAllProviders() {
        return [
            SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                Setup_Guidance__c
            FROM Hr_Integration_Provider__mdt
            ORDER BY Provider_Key__c ASC
        ];
    }

    @TestVisible
    private static HrAbsenceSyncProvider createAbsenceProvider(Hr_Integration_Provider__mdt provider) {
        switch on provider.Provider_Key__c {
            when 'Workday' {
                return new WorkdayAbsenceSyncProvider(provider);
            }
            when 'UKG' {
                return new UkgAbsenceSyncProvider(provider);
            }
            when 'ADP' {
                return new AdpAbsenceSyncProvider(provider);
            }
            when 'SuccessFactors' {
                return new SuccessFactorsAbsenceSyncProvider(provider);
            }
            when else {
                return null;
            }
        }
    }

    @TestVisible
    private static HrScheduleSyncProvider createScheduleProvider(Hr_Integration_Provider__mdt provider) {
        switch on provider.Provider_Key__c {
            when 'Workday' {
                return new WorkdayScheduleSyncProvider(provider);
            }
            when 'UKG' {
                return new UkgScheduleSyncProvider(provider);
            }
            when 'ADP' {
                return new AdpScheduleSyncProvider(provider);
            }
            when 'SuccessFactors' {
                return new SuccessFactorsScheduleSyncProvider(provider);
            }
            when else {
                return null;
            }
        }
    }

    public class HrSyncResult {
        public List<ProviderSyncResult> absenceResults = new List<ProviderSyncResult>();
        public List<ProviderSyncResult> scheduleResults = new List<ProviderSyncResult>();
    }

    public class ProviderSyncResult {
        public String providerKey;
        public Integer upserted = 0;
        public Integer cancelled = 0;
        public Integer skipped = 0;
        public List<String> errors = new List<String>();

        public ProviderSyncResult(String key) {
            providerKey = key;
        }
    }
}
