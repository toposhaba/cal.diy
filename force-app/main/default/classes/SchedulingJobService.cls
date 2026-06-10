public with sharing class SchedulingJobService {

    private static final String CALENDAR_SYNC_JOB = 'CalDIY_CalendarSync';
    private static final String WORKFLOW_REMINDER_JOB = 'CalDIY_WorkflowReminder';
    private static final String HR_WORKFORCE_SYNC_JOB = 'CalDIY_HrWorkforceSync';

    public static void scheduleAllJobs() {
        scheduleCalendarSync();
        scheduleWorkflowReminders();
        scheduleHrWorkforceSync();
    }

    public static Id scheduleCalendarSync() {
        abortJob(CALENDAR_SYNC_JOB);
        return System.schedule(CALENDAR_SYNC_JOB, '0 0 * * * ?', new CalendarSyncSchedulable());
    }

    public static Id scheduleWorkflowReminders() {
        abortJob(WORKFLOW_REMINDER_JOB);
        return System.schedule(WORKFLOW_REMINDER_JOB, '0 0 * * * ?', new WorkflowReminderSchedulable());
    }

    public static Id scheduleHrWorkforceSync() {
        abortJob(HR_WORKFORCE_SYNC_JOB);
        return System.schedule(HR_WORKFORCE_SYNC_JOB, '0 30 * * * ?', new HrWorkforceSyncSchedulable());
    }

    public static void abortJob(String jobName) {
        for (CronTrigger job : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
        ]) {
            System.abortJob(job.Id);
        }
    }
}
