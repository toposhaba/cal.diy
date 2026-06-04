@IsTest
private class SchedulingJobServiceTest {

    @IsTest
    static void testScheduleAllJobs() {
        Test.startTest();
        SchedulingJobService.scheduleAllJobs();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name IN ('CalDIY_CalendarSync', 'CalDIY_WorkflowReminder')
        ];
        System.assertEquals(2, jobs.size());
    }

    @IsTest
    static void testRescheduleJobsReplacesExisting() {
        Test.startTest();
        SchedulingJobService.scheduleAllJobs();
        SchedulingJobService.scheduleAllJobs();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'CalDIY_CalendarSync'
        ];
        System.assertEquals(1, jobs.size());
    }
}
