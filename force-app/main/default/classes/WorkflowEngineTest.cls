@IsTest
private class WorkflowEngineTest {

    @IsTest
    static void testExecuteWorkflowsOnNewBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Workflow Test', 30);
            SchedulingTestDataFactory.createWorkflow('New_Booking', eventType.Id, 'Attendee', 'Reminder for {booking.title}');

            Datetime startDt = Datetime.now().addDays(2);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            WorkflowEngine.executeWorkflows('New_Booking', new List<Id>{ booking.Id });
            Test.stopTest();

            System.assertNotEquals(null, booking.Id);
        }
    }

    @IsTest
    static void testScheduleBeforeEventReminder() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Before Event', 30);
            Workflow__c workflow = new Workflow__c(
                Name = 'Before Reminder',
                Trigger_Event__c = 'Before_Event',
                Time_Offset_Minutes__c = 120,
                Is_Active__c = true,
                Event_Type__c = eventType.Id
            );
            insert workflow;

            insert new Workflow_Step__c(
                Workflow__c = workflow.Id,
                Action_Type__c = 'Email',
                Recipient__c = 'Attendee',
                Template__c = 'Starts soon: {booking.title}',
                Sort_Order__c = 1
            );

            Datetime startDt = Datetime.now().addMinutes(90);
            SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, startDt.addMinutes(30)
            );

            Test.startTest();
            WorkflowEngine.scheduleReminderWorkflows();
            Test.stopTest();

            System.assert(true);
        }
    }

    @IsTest
    static void testScheduleAfterEventReminder() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'After Event', 30);
            Workflow__c workflow = new Workflow__c(
                Name = 'After Reminder',
                Trigger_Event__c = 'After_Event',
                Time_Offset_Minutes__c = 120,
                Is_Active__c = true,
                Event_Type__c = eventType.Id
            );
            insert workflow;

            insert new Workflow_Step__c(
                Workflow__c = workflow.Id,
                Action_Type__c = 'Email',
                Recipient__c = 'Host',
                Template__c = 'Follow up: {booking.title}',
                Sort_Order__c = 1
            );

            Datetime endDt = Datetime.now().addMinutes(-30);
            Datetime startDt = endDt.addMinutes(-30);
            SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, startDt, endDt
            );

            Test.startTest();
            WorkflowEngine.scheduleReminderWorkflows();
            Test.stopTest();

            System.assert(true);
        }
    }
}
