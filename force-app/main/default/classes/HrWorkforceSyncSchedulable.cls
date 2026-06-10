public with sharing class HrWorkforceSyncSchedulable implements Schedulable {

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new HrWorkforceSyncBatch(), 1);
    }
}
