@IsTest
private class RecordBookingsControllerTest {

    @IsTest
    static void testGetBookingsForContact() {
        User host = SchedulingTestDataFactory.createTestUser();
        Account account = new Account(Name = 'Test Account');
        insert account;

        Contact contact = new Contact(
            FirstName = 'Booker',
            LastName = 'Contact',
            Email = 'booker.contact@example.com',
            AccountId = account.Id
        );
        insert contact;

        Event_Type__c eventType;
        Booking__c linkedBooking;
        Booking__c emailBooking;
        System.runAs(host) {
            eventType = SchedulingTestDataFactory.createEventType(host.Id, 'Contact Event', 30);
            Datetime startDt = Datetime.now().addDays(2);
            linkedBooking = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt, startDt.addMinutes(30)
            );
            linkedBooking.Booker_Contact__c = contact.Id;
            linkedBooking.Booker_Email__c = contact.Email;
            update linkedBooking;

            emailBooking = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt.addDays(1), startDt.addDays(1).addMinutes(30)
            );
            emailBooking.Booker_Contact__c = null;
            emailBooking.Booker_Email__c = contact.Email;
            update emailBooking;
        }

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse response =
                RecordBookingsController.getBookingsForRecord(contact.Id, 'Contact');
            Test.stopTest();

            System.assertEquals('Contact', response.contextType);
            System.assertEquals(2, response.bookings.size(), 'Should match contact link and email');
            System.assertEquals(null, response.emptyMessage);
        }
    }

    @IsTest
    static void testGetBookingsForAccount() {
        User host = SchedulingTestDataFactory.createTestUser();
        Account account = new Account(Name = 'Account Bookings');
        insert account;

        Contact contactOne = new Contact(
            FirstName = 'One',
            LastName = 'Contact',
            Email = 'one@example.com',
            AccountId = account.Id
        );
        Contact contactTwo = new Contact(
            FirstName = 'Two',
            LastName = 'Contact',
            Email = 'two@example.com',
            AccountId = account.Id
        );
        insert new List<Contact>{ contactOne, contactTwo };

        System.runAs(host) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host.Id, 'Account Event', 30);
            Datetime startDt = Datetime.now().addDays(3);

            Booking__c bookingOne = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt, startDt.addMinutes(30)
            );
            bookingOne.Booker_Contact__c = contactOne.Id;
            update bookingOne;

            Booking__c bookingTwo = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt.addDays(1), startDt.addDays(1).addMinutes(30)
            );
            bookingTwo.Booker_Contact__c = contactTwo.Id;
            update bookingTwo;
        }

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse response =
                RecordBookingsController.getBookingsForRecord(account.Id, 'Account');
            Test.stopTest();

            System.assertEquals('Account', response.contextType);
            System.assertEquals(2, response.bookings.size());
        }
    }

    @IsTest
    static void testGetBookingsForOpportunity() {
        User host = SchedulingTestDataFactory.createTestUser();
        Account account = new Account(Name = 'Opp Account');
        insert account;

        Contact contact = new Contact(
            FirstName = 'Opp',
            LastName = 'Contact',
            Email = 'opp.contact@example.com',
            AccountId = account.Id
        );
        insert contact;

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;

        insert new OpportunityContactRole(
            OpportunityId = opportunity.Id,
            ContactId = contact.Id,
            Role = 'Decision Maker'
        );

        System.runAs(host) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host.Id, 'Opp Event', 30);
            Datetime startDt = Datetime.now().addDays(4);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt, startDt.addMinutes(30)
            );
            booking.Booker_Contact__c = contact.Id;
            update booking;
        }

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse response =
                RecordBookingsController.getBookingsForRecord(opportunity.Id, 'Opportunity');
            Test.stopTest();

            System.assertEquals('Opportunity', response.contextType);
            System.assertEquals(1, response.bookings.size());
            System.assertEquals('Test Booking', response.bookings[0].title);
        }
    }

    @IsTest
    static void testEmptyStatesAndValidation() {
        User host = SchedulingTestDataFactory.createTestUser();
        Account account = new Account(Name = 'Empty Account');
        insert account;

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse accountResponse =
                RecordBookingsController.getBookingsForRecord(account.Id, 'Account');
            Test.stopTest();

            System.assertEquals('Account', accountResponse.contextType);
            System.assertEquals(0, accountResponse.bookings.size());
            System.assertEquals(
                'No bookings found for contacts on this account.',
                accountResponse.emptyMessage
            );
        }

        Boolean threwForNull = false;
        try {
            RecordBookingsController.getBookingsForRecord(null, 'Account');
        } catch (AuraHandledException ex) {
            threwForNull = true;
            System.assertEquals('Record ID is required', ex.getMessage());
        }
        System.assertEquals(true, threwForNull);
    }

    @IsTest
    static void testGetBookingsForGenericCase() {
        User host = SchedulingTestDataFactory.createTestUser();

        Contact contact;
        Case supportCase;
        System.runAs(host) {
            contact = new Contact(
                FirstName = 'Case',
                LastName = 'Contact',
                Email = 'case.contact@example.com'
            );
            insert contact;

            supportCase = new Case(
                Subject = 'Booking Case',
                ContactId = contact.Id,
                Status = 'New',
                Origin = 'Phone'
            );
            insert supportCase;

            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(host.Id, 'Case Event', 30);
            Datetime startDt = Datetime.now().addDays(5);
            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, host.Id, startDt, startDt.addMinutes(30)
            );
            booking.Booker_Contact__c = contact.Id;
            booking.Booker_Email__c = contact.Email;
            update booking;
        }

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse response =
                RecordBookingsController.getBookingsForRecord(supportCase.Id, 'Case');
            Test.stopTest();

            System.assertEquals('Generic', response.contextType);
            System.assertEquals(1, response.bookings.size());
        }
    }

    @IsTest
    static void testGenericWithoutContactLookups() {
        Product2 product = new Product2(Name = 'No Contact Product', IsActive = true);
        insert product;

        Test.startTest();
        RecordBookingsController.RecordBookingsResponse response =
            RecordBookingsController.getBookingsForRecord(product.Id, 'Product2');
        Test.stopTest();

        System.assertEquals('Generic', response.contextType);
        System.assertEquals(0, response.bookings.size());
        System.assertEquals(
            'No contact lookup fields found on this record.',
            response.emptyMessage
        );
    }

    @IsTest
    static void testObjectTypeMismatch() {
        Contact contact = new Contact(FirstName = 'Mismatch', LastName = 'Test', Email = 'm@example.com');
        insert contact;

        Boolean threwMismatch = false;
        try {
            RecordBookingsController.getBookingsForRecord(contact.Id, 'Account');
        } catch (AuraHandledException ex) {
            threwMismatch = true;
            System.assertEquals('Record ID does not match the object type', ex.getMessage());
        }
        System.assertEquals(true, threwMismatch);
    }

    @IsTest
    static void testResolveObjectApiNameFromRecordIdOnly() {
        User host = SchedulingTestDataFactory.createTestUser();
        Contact contact = new Contact(FirstName = 'Derived', LastName = 'Type', Email = 'derived@example.com');
        insert contact;

        System.runAs(host) {
            Test.startTest();
            RecordBookingsController.RecordBookingsResponse response =
                RecordBookingsController.getBookingsForRecord(contact.Id, null);
            Test.stopTest();

            System.assertEquals('Contact', response.contextType);
        }
    }
}
