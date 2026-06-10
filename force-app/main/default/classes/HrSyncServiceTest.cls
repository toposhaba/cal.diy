@IsTest
private class HrSyncServiceTest {

    @IsTest
    static void syncAll_returnsEmptyWhenNoProvidersEnabled() {
        Test.startTest();
        HrSyncService.HrSyncResult result = HrSyncService.syncAll();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void getAllProviders_returnsRegisteredProviders() {
        List<Hr_Integration_Provider__mdt> providers = HrSyncService.getAllProviders();
        System.assert(providers.size() >= 4);
        Set<String> keys = new Set<String>();
        for (Hr_Integration_Provider__mdt provider : providers) {
            keys.add(provider.Provider_Key__c);
        }
        System.assert(keys.contains('Workday'));
        System.assert(keys.contains('UKG'));
        System.assert(keys.contains('ADP'));
        System.assert(keys.contains('SuccessFactors'));
    }

    @IsTest
    static void parseReportRows_supportsMultipleFormats() {
        List<Object> fromArray = HrReportClient.parseReportRows('[{"id":"1"}]');
        System.assertEquals(1, fromArray.size());

        List<Object> fromReportEntry = HrReportClient.parseReportRows('{"Report_Entry":[{"id":"2"}]}');
        System.assertEquals(1, fromReportEntry.size());

        List<Object> empty = HrReportClient.parseReportRows('{}');
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void parseDateAndTimeValues() {
        System.assertEquals(Date.newInstance(2026, 6, 5), HrReportClient.parseDateValue('2026-06-05'));
        System.assertEquals(Time.newInstance(9, 30, 0, 0), HrReportClient.parseTimeValue('09:30:00'));
        System.assertEquals(null, HrReportClient.parseDateValue(null));
    }

    @IsTest
    static void userResolver_mapsWorkerAndEmail() {
        User testUser = SchedulingTestDataFactory.createTestUser();
        testUser.Workday_Worker_Id__c = 'WD-RESOLVE';
        update testUser;

        Map<String, Id> workerMap = HrUserResolver.buildWorkerIdMap('Workday_Worker_Id__c');
        Map<String, Id> emailMap = HrUserResolver.buildEmailMap();

        Id byWorker = HrUserResolver.resolveUser('WD-RESOLVE', null, workerMap, emailMap);
        Id byEmail = HrUserResolver.resolveUser(null, testUser.Email, workerMap, emailMap);

        System.assertEquals(testUser.Id, byWorker);
        System.assertEquals(testUser.Id, byEmail);
    }

    @IsTest
    static void stubProviders_returnNotImplementedMessages() {
        Hr_Integration_Provider__mdt provider = [
            SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                Setup_Guidance__c
            FROM Hr_Integration_Provider__mdt
            WHERE Provider_Key__c = 'UKG'
            LIMIT 1
        ];

        HrSyncService.ProviderSyncResult absenceResult = new UkgAbsenceSyncProvider(provider).syncAbsences();
        HrSyncService.ProviderSyncResult scheduleResult = new UkgScheduleSyncProvider(provider).syncSchedules();

        System.assert(!absenceResult.errors.isEmpty());
        System.assert(!scheduleResult.errors.isEmpty());
    }
}
