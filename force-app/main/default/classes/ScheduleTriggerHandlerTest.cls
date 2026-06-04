@IsTest
private class ScheduleTriggerHandlerTest {

    @IsTest
    static void testOwnerUserDefaultedFromOwner() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Schedule__c schedule = new Schedule__c(
                Name = 'Trigger Schedule',
                Time_Zone__c = 'America/New_York',
                Is_Default__c = true
            );

            Test.startTest();
            insert schedule;
            Test.stopTest();

            Schedule__c inserted = [
                SELECT Owner_User__c
                FROM Schedule__c
                WHERE Id = :schedule.Id
            ];
            System.assertEquals(testUser.Id, inserted.Owner_User__c);
        }
    }
}
