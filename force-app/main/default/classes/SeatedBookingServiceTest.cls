@IsTest
private class SeatedBookingServiceTest {

    @IsTest
    static void testReserveSeat() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Group Class', 60);
            eventType.Seats_Per_Slot__c = 5;
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(60)
            );

            Test.startTest();
            Booking_Seat__c seat = SeatedBookingService.reserveSeat(
                booking.Id, 'Student One', 'student1@example.com'
            );
            Test.stopTest();

            System.assertNotEquals(null, seat.Id);
            System.assertEquals('Reserved', seat.Status__c);
        }
    }

    @IsTest
    static void testSeatsFull() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Small Group', 60);
            eventType.Seats_Per_Slot__c = 1;
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(60)
            );

            SeatedBookingService.reserveSeat(booking.Id, 'First', 'first@example.com');

            Test.startTest();
            try {
                SeatedBookingService.reserveSeat(booking.Id, 'Second', 'second@example.com');
                System.assert(false, 'Should throw seats full');
            } catch (SchedulingException e) {
                System.assertEquals('SEATS_FULL', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCancelSeat() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Cancel Seat', 60);
            eventType.Seats_Per_Slot__c = 5;
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(60)
            );

            Booking_Seat__c seat = SeatedBookingService.reserveSeat(booking.Id, 'Canceller', 'cancel@example.com');

            Test.startTest();
            SeatedBookingService.cancelSeat(seat.Id);
            Test.stopTest();

            Booking_Seat__c updated = [SELECT Status__c FROM Booking_Seat__c WHERE Id = :seat.Id];
            System.assertEquals('Cancelled', updated.Status__c);
        }
    }

    @IsTest
    static void testGetAvailableSeats() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Count Seats', 60);
            eventType.Seats_Per_Slot__c = 3;
            update eventType;

            Datetime start = Datetime.now().addDays(7);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, start, start.addMinutes(60)
            );

            SeatedBookingService.reserveSeat(booking.Id, 'One', 'one@example.com');

            Test.startTest();
            Integer available = SeatedBookingService.getAvailableSeats(booking.Id);
            Test.stopTest();

            System.assertEquals(2, available);
        }
    }

    @IsTest
    static void testFindOrCreateSeatedBooking() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Seated', 60);
            eventType.Seats_Per_Slot__c = 10;
            update eventType;

            Datetime start = Datetime.now().addDays(14);

            Test.startTest();
            Booking__c booking = SeatedBookingService.findOrCreateSeatedBooking(eventType.Id, start);
            Booking__c same = SeatedBookingService.findOrCreateSeatedBooking(eventType.Id, start);
            Test.stopTest();

            System.assertEquals(booking.Id, same.Id, 'Should reuse existing booking for same slot');
        }
    }
}
