public with sharing class SchedulingJobService {

    private static final String CALENDAR_SYNC_JOB = 'CalDIY_CalendarSync';
    private static final String WORKFLOW_REMINDER_JOB = 'CalDIY_WorkflowReminder';

    public static void scheduleAllJobs() {
        scheduleCalendarSync();
        scheduleWorkflowReminders();
    }

    public static Id scheduleCalendarSync() {
        abortJob(CALENDAR_SYNC_JOB);
        return System.schedule(CALENDAR_SYNC_JOB, '0 0 * * * ?', new CalendarSyncSchedulable());
    }

    public static Id scheduleWorkflowReminders() {
        abortJob(WORKFLOW_REMINDER_JOB);
        return System.schedule(WORKFLOW_REMINDER_JOB, '0 0 * * * ?', new WorkflowReminderSchedulable());
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
