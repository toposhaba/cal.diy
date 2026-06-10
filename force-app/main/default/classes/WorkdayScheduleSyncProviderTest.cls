@IsTest
private class WorkdayScheduleSyncProviderTest {

    @IsTest
    static void syncSchedules_createsDefaultScheduleAndWindows() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            testUser.Workday_Worker_Id__c = 'WD-300';
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
                        'Worker_ID' => 'WD-300',
                        'Schedule_ID' => 'SCH-1',
                        'Day_of_Week' => 'Monday',
                        'Start_Time' => '09:00:00',
                        'End_Time' => '17:00:00',
                        'Time_Zone' => 'America/New_York'
                    },
                    new Map<String, Object>{
                        'Worker_ID' => 'WD-300',
                        'Schedule_ID' => 'SCH-1',
                        'Day_of_Week' => 'Wednesday',
                        'Start_Time' => '10:00:00',
                        'End_Time' => '16:00:00',
                        'Time_Zone' => 'America/New_York'
                    }
                }
            });

            Test.startTest();
            HrSyncService.ProviderSyncResult result = new WorkdayScheduleSyncProvider(provider).syncSchedules();
            Test.stopTest();

            System.assertEquals(0, result.errors.size(), String.join(result.errors, '; '));
            System.assert(result.upserted > 0, 'Expected schedule records to be created');
            List<Schedule__c> schedules = [
                SELECT Id, Owner_User__c, Is_Default__c, Source__c, External_Id__c, Time_Zone__c
                FROM Schedule__c
                WHERE Owner_User__c = :testUser.Id AND Source__c = 'Workday'
            ];
            System.assertEquals(1, schedules.size());
            System.assertEquals(true, schedules[0].Is_Default__c);
            System.assertEquals('Workday:schedule:SCH-1', schedules[0].External_Id__c);

            List<Availability__c> windows = [
                SELECT Id, Days__c, Start_Time__c, End_Time__c, Source__c
                FROM Availability__c
                WHERE Schedule__c = :schedules[0].Id AND Source__c = 'Workday'
            ];
            System.assertEquals(2, windows.size());
            Set<String> days = new Set<String>();
            for (Availability__c window : windows) {
                days.add(window.Days__c);
            }
            System.assert(days.contains('Monday'));
            System.assert(days.contains('Wednesday'));
        }
    }
}
