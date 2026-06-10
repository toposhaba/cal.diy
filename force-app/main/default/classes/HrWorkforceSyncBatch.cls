public without sharing class HrWorkforceSyncBatch implements Database.Batchable<String>, Database.AllowsCallouts {

    public Iterable<String> start(Database.BatchableContext bc) {
        return new List<String>{ 'sync' };
    }

    public void execute(Database.BatchableContext bc, List<String> scope) {
        try {
            HrSyncService.syncAll();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'HR workforce sync failed: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'HR workforce sync batch completed');
    }
}
