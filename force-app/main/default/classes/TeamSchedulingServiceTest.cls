@IsTest
private class TeamSchedulingServiceTest {

    @IsTest
    static void testRoundRobinAssignment() {
        User host1 = SchedulingTestDataFactory.createTestUser();
        User host2 = SchedulingTestDataFactory.createTestUser();

        System.runAs(host1) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host1.Id, 'Team Event', 30);
            eventType.Scheduling_Type__c = 'Round_Robin';
            update eventType;

            Event_Type_Host__c eth1 = new Event_Type_Host__c(
                Event_Type__c = eventType.Id, User__c = host1.Id, Priority__c = 1, Weight__c = 100
            );
            Event_Type_Host__c eth2 = new Event_Type_Host__c(
                Event_Type__c = eventType.Id, User__c = host2.Id, Priority__c = 1, Weight__c = 100
            );
            insert new List<Event_Type_Host__c>{ eth1, eth2 };

            Datetime futureSlot = Datetime.now().addDays(7);

            Test.startTest();
            Id assignedHost = TeamSchedulingService.assignRoundRobinHost(
                eventType.Id, futureSlot, futureSlot.addMinutes(30)
            );
            Test.stopTest();

            System.assert(assignedHost == host1.Id || assignedHost == host2.Id, 'Should assign one of the hosts');
        }
    }

    @IsTest
    static void testRoundRobinNoHosts() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Empty', 30);

            Test.startTest();
            try {
                TeamSchedulingService.assignRoundRobinHost(
                    eventType.Id, Datetime.now().addDays(7), Datetime.now().addDays(7).addMinutes(30)
                );
                System.assert(false, 'Should throw');
            } catch (SchedulingException e) {
                System.assertEquals('NO_HOSTS', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCollectiveHosts() {
        User host1 = SchedulingTestDataFactory.createTestUser();
        User host2 = SchedulingTestDataFactory.createTestUser();

        System.runAs(host1) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host1.Id, 'Collective', 30);

            insert new List<Event_Type_Host__c>{
                new Event_Type_Host__c(Event_Type__c = eventType.Id, User__c = host1.Id, Is_Fixed__c = true),
                new Event_Type_Host__c(Event_Type__c = eventType.Id, User__c = host2.Id, Is_Fixed__c = true)
            };

            Test.startTest();
            List<Id> hosts = TeamSchedulingService.getCollectiveHosts(eventType.Id);
            Test.stopTest();

            System.assertEquals(2, hosts.size());
        }
    }

    @IsTest
    static void testAreAllHostsAvailable() {
        User host1 = SchedulingTestDataFactory.createTestUser();

        System.runAs(host1) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host1.Id, 'Avail Check', 30);
            insert new Event_Type_Host__c(Event_Type__c = eventType.Id, User__c = host1.Id, Is_Fixed__c = true);

            Datetime futureSlot = Datetime.now().addDays(14);

            Test.startTest();
            Boolean available = TeamSchedulingService.areAllHostsAvailable(
                eventType.Id, futureSlot, futureSlot.addMinutes(30)
            );
            Test.stopTest();

            System.assertEquals(true, available);
        }
    }

    @IsTest
    static void testHostBlockedByOOO() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'OOO Test', 30);
            insert new Event_Type_Host__c(Event_Type__c = eventType.Id, User__c = testUser.Id, Is_Fixed__c = true);

            Date oooDate = Date.today().addDays(7);
            insert new Out_of_Office__c(
                User__c = testUser.Id,
                Start_Date__c = oooDate,
                End_Date__c = oooDate.addDays(3)
            );

            Datetime slotDuringOOO = Datetime.newInstance(oooDate.addDays(1), Time.newInstance(10, 0, 0, 0));

            Test.startTest();
            Boolean available = TeamSchedulingService.areAllHostsAvailable(
                eventType.Id, slotDuringOOO, slotDuringOOO.addMinutes(30)
            );
            Test.stopTest();

            System.assertEquals(false, available, 'Should be blocked by OOO');
        }
    }
}
