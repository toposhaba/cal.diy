public with sharing class WorkflowReminderSchedulable implements Schedulable {

    public void execute(SchedulableContext ctx) {
        WorkflowEngine.scheduleReminderWorkflows();
    }
}
