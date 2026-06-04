@IsTest
private class BookingFieldServiceTest {

    @IsTest
    static void testGetFieldsAndSaveResponses() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Custom Fields', 30);
            Booking_Field__c field = new Booking_Field__c(
                Event_Type__c = eventType.Id,
                Name = 'Company',
                Field_Type__c = 'Text',
                Is_Required__c = true,
                Sort_Order__c = 1
            );
            insert field;

            List<BookingFieldService.FieldInfo> fields =
                BookingFieldService.getFieldsForEventType(eventType.Id);
            System.assertEquals(1, fields.size());
            System.assertEquals('Company', fields[0].name);

            Booking__c booking = SchedulingTestDataFactory.createBooking(
                eventType.Id, testUser.Id, Datetime.now().addDays(3), Datetime.now().addDays(3).addMinutes(30)
            );

            BookingFieldService.saveResponses(
                booking.Id,
                new Map<Id, String>{ field.Id => 'Acme Corp' }
            );

            Booking_Field_Response__c response = [
                SELECT Value__c FROM Booking_Field_Response__c
                WHERE Booking__c = :booking.Id AND Booking_Field__c = :field.Id
                LIMIT 1
            ];
            System.assertEquals('Acme Corp', response.Value__c);
        }
    }

    @IsTest
    static void testValidateRequiredField() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Required Field', 30);
            Booking_Field__c field = new Booking_Field__c(
                Event_Type__c = eventType.Id,
                Name = 'Topic',
                Field_Type__c = 'Text',
                Is_Required__c = true
            );
            insert field;

            try {
                BookingFieldService.validateRequiredFields(eventType.Id, new Map<Id, String>());
                System.assert(false, 'Expected required field validation');
            } catch (SchedulingException e) {
                System.assertEquals('REQUIRED_FIELD', e.getErrorCode());
            }
        }
    }
}
