@IsTest
private class WorkdayAbsenceServiceTest {

    @IsTest
    static void syncApprovedAbsences_createsOutOfOfficeFromReport() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            testUser.Workday_Worker_Id__c = 'WD-100';
            update testUser;

            Hr_Integration_Provider__mdt provider = [
                SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                    Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                    Setup_Guidance__c
                FROM Hr_Integration_Provider__mdt
                WHERE Provider_Key__c = 'Workday'
                LIMIT 1
            ];

            HrReportClient.skipCallouts = true;
            HrReportClient.mockResponseBody = JSON.serialize(new Map<String, Object>{
                'Report_Entry' => new List<Object>{
                    new Map<String, Object>{
                        'Absence_ID' => 'A-1',
                        'Worker_ID' => 'WD-100',
                        'Start_Date' => String.valueOf(Date.today().addDays(7)),
                        'End_Date' => String.valueOf(Date.today().addDays(9)),
                        'Absence_Type' => 'PTO',
                        'Status' => 'Approved'
                    }
                }
            });

            Test.startTest();
            HrSyncService.ProviderSyncResult result = new WorkdayAbsenceSyncProvider(provider).syncAbsences();
            Test.stopTest();

            System.assertEquals(0, result.errors.size(), String.join(result.errors, '; '));
            System.assertEquals(1, result.upserted, 'Expected one absence upsert');
            List<Out_of_Office__c> records = [
                SELECT Id, User__c, Source__c, Status__c, Absence_Type__c, External_Id__c
                FROM Out_of_Office__c
                WHERE External_Id__c = 'Workday:A-1'
            ];
            System.assertEquals(1, records.size());
            System.assertEquals(testUser.Id, records[0].User__c);
            System.assertEquals('Workday', records[0].Source__c);
            System.assertEquals('Approved', records[0].Status__c);
            System.assertEquals('PTO', records[0].Absence_Type__c);
        }
    }

    @IsTest
    static void syncApprovedAbsences_cancelsStaleRecords() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            testUser.Workday_Worker_Id__c = 'WD-200';
            update testUser;

            insert new Out_of_Office__c(
                User__c = testUser.Id,
                Start_Date__c = Date.today().addDays(1),
                End_Date__c = Date.today().addDays(1),
                Source__c = 'Workday',
                Status__c = 'Approved',
                External_Id__c = 'Workday:OLD-1',
                Reason__c = 'Old absence'
            );

            Hr_Integration_Provider__mdt provider = [
                SELECT Provider_Key__c, Is_Enabled__c, Is_Implemented__c, Named_Credential__c,
                    Absence_Report_Path__c, Schedule_Report_Path__c, Worker_Id_User_Field__c,
                    Setup_Guidance__c
                FROM Hr_Integration_Provider__mdt
                WHERE Provider_Key__c = 'Workday'
                LIMIT 1
            ];

            HrReportClient.skipCallouts = true;
            HrReportClient.mockResponseBody = '{"Report_Entry":[]}';

            Test.startTest();
            HrSyncService.ProviderSyncResult result = new WorkdayAbsenceSyncProvider(provider).syncAbsences();
            Test.stopTest();

            System.assertEquals(1, result.cancelled);
            Out_of_Office__c stale = [
                SELECT Status__c FROM Out_of_Office__c WHERE External_Id__c = 'Workday:OLD-1' LIMIT 1
            ];
            System.assertEquals('Cancelled', stale.Status__c);
        }
    }

    @IsTest
    static void workdayAbsenceService_delegatesToProvider() {
        HrReportClient.skipCallouts = true;
        HrReportClient.mockResponseBody = '{"Report_Entry":[]}';
        HrSyncService.ProviderSyncResult result = WorkdayAbsenceService.syncApprovedAbsences();
        System.assertEquals('Workday', result.providerKey);
    }
}
