@IsTest
private class CalendarConnectionControllerTest {

    @IsTest
    static void testCreateAndToggleConnection() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Calendar_Connection__c conn = CalendarConnectionController.createConnection(
                'Salesforce', 'primary', true, false
            );
            CalendarConnectionController.toggleConnection(conn.Id);
            Test.stopTest();

            Calendar_Connection__c updated = [
                SELECT Is_Active__c
                FROM Calendar_Connection__c
                WHERE Id = :conn.Id
            ];
            System.assertEquals(false, updated.Is_Active__c);
        }
    }

    @IsTest
    static void testGetConnectionsAndDelete() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Calendar_Connection__c conn = CalendarConnectionController.createConnection(
                'Salesforce', null, true, true
            );

            Test.startTest();
            List<Calendar_Connection__c> connections = CalendarConnectionController.getConnections();
            CalendarConnectionController.deleteConnection(conn.Id);
            Test.stopTest();

            System.assertEquals(1, connections.size());
            System.assertEquals(0, [SELECT COUNT() FROM Calendar_Connection__c WHERE Id = :conn.Id]);
        }
    }

    @IsTest
    static void testNamedCredentialAuthUrl() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> google = CalendarConnectionController.getNamedCredentialAuthUrl('Google');
            Map<String, Object> verify = CalendarConnectionController.verifyConnection('Salesforce');
            Test.stopTest();

            System.assertEquals('oauth', google.get('type'));
            System.assertEquals(true, verify.get('authenticated'));
        }
    }
}
