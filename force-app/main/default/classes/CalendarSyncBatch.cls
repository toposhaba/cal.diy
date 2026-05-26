public with sharing class CalendarSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Owner_User__c, Provider__c, Calendar_Id__c, Last_Sync__c
            FROM Calendar_Connection__c
            WHERE Is_Active__c = true AND Push_Events_To__c = true
            ORDER BY Last_Sync__c ASC NULLS FIRST
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Calendar_Connection__c> connections) {
        List<Calendar_Connection__c> toUpdate = new List<Calendar_Connection__c>();

        for (Calendar_Connection__c conn : connections) {
            try {
                syncConnectionBookings(conn);
                conn.Last_Sync__c = Datetime.now();
                toUpdate.add(conn);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Sync failed for connection ' + conn.Id + ': ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'Calendar sync batch completed');
    }

    private void syncConnectionBookings(Calendar_Connection__c conn) {
        List<Booking__c> unsyncedBookings = [
            SELECT Id, External_Event_Id__c
            FROM Booking__c
            WHERE Host__c = :conn.Owner_User__c
                AND Status__c = 'Accepted'
                AND External_Event_Id__c = null
                AND Start_DateTime__c >= :Datetime.now()
            WITH USER_MODE
            ORDER BY Start_DateTime__c ASC
            LIMIT 20
        ];

        for (Booking__c booking : unsyncedBookings) {
            try {
                CalendarIntegrationService.createExternalEvent(booking.Id);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Failed to sync booking ' + booking.Id + ': ' + e.getMessage());
            }
        }
    }
}
