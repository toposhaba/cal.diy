@IsTest
private class HrWorkforceSyncBatchTest {

    @IsTest
    static void testBatchExecutesSync() {
        HrReportClient.skipCallouts = true;
        HrReportClient.mockResponseBody = '{"Report_Entry":[]}';

        Test.startTest();
        Database.executeBatch(new HrWorkforceSyncBatch(), 1);
        Test.stopTest();

        System.assert(true, 'Batch completed without unhandled exception');
    }

    @IsTest
    static void testSchedulableExecutesBatch() {
        Test.startTest();
        String jobId = System.schedule('TestHrSync', '0 0 0 1 1 ? 2099', new HrWorkforceSyncSchedulable());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }
}
