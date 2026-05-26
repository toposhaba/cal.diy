public with sharing class CalendarSyncSchedulable implements Schedulable {

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new CalendarSyncBatch(), 10);
    }
}
