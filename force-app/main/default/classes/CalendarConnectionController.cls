public with sharing class CalendarConnectionController {

    @AuraEnabled(cacheable=true)
    public static List<Calendar_Connection__c> getConnections() {
        return [
            SELECT Id, Name, Provider__c, Calendar_Id__c, Is_Active__c,
                   Check_For_Conflicts__c, Push_Events_To__c, Last_Sync__c
            FROM Calendar_Connection__c
            WHERE Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            ORDER BY Provider__c ASC
        ];
    }

    @AuraEnabled
    public static Calendar_Connection__c createConnection(
        String provider, String calendarId, Boolean checkConflicts, Boolean pushEvents
    ) {
        if (String.isBlank(provider)) {
            throw new AuraHandledException('Provider is required');
        }

        Calendar_Connection__c conn = new Calendar_Connection__c(
            Name = provider + ' Calendar',
            Owner_User__c = UserInfo.getUserId(),
            Provider__c = provider,
            Calendar_Id__c = calendarId,
            Is_Active__c = true,
            Check_For_Conflicts__c = checkConflicts,
            Push_Events_To__c = pushEvents
        );
        insert as user conn;
        return conn;
    }

    @AuraEnabled
    public static void toggleConnection(Id connectionId) {
        Calendar_Connection__c conn = [
            SELECT Id, Is_Active__c
            FROM Calendar_Connection__c
            WHERE Id = :connectionId AND Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (conn == null) {
            throw new AuraHandledException('Connection not found');
        }

        conn.Is_Active__c = !conn.Is_Active__c;
        update as user conn;
    }

    @AuraEnabled
    public static void deleteConnection(Id connectionId) {
        Calendar_Connection__c conn = [
            SELECT Id
            FROM Calendar_Connection__c
            WHERE Id = :connectionId AND Owner_User__c = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (conn == null) {
            throw new AuraHandledException('Connection not found');
        }

        delete as user conn;
    }
}
