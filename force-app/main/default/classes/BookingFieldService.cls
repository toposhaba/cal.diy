public with sharing class BookingFieldService {

    public class FieldInfo {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public List<String> options { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }
    }

    public static List<FieldInfo> getFieldsForEventType(Id eventTypeId) {
        List<FieldInfo> fields = new List<FieldInfo>();
        for (Booking_Field__c field : [
            SELECT Id, Name, Field_Type__c, Options__c, Is_Required__c, Sort_Order__c
            FROM Booking_Field__c
            WHERE Event_Type__c = :eventTypeId
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC
        ]) {
            FieldInfo info = new FieldInfo();
            info.id = field.Id;
            info.name = field.Name;
            info.fieldType = field.Field_Type__c;
            info.options = parseOptions(field.Options__c);
            info.required = field.Is_Required__c == true;
            info.sortOrder = field.Sort_Order__c != null ? Integer.valueOf(field.Sort_Order__c) : 0;
            fields.add(info);
        }
        return fields;
    }

    public static void saveResponses(Id bookingId, Map<Id, String> responses) {
        if (bookingId == null || responses == null || responses.isEmpty()) {
            return;
        }

        List<Booking_Field_Response__c> records = new List<Booking_Field_Response__c>();
        for (Id fieldId : responses.keySet()) {
            records.add(new Booking_Field_Response__c(
                Booking__c = bookingId,
                Booking_Field__c = fieldId,
                Value__c = responses.get(fieldId)
            ));
        }
        insert as user records;
    }

    public static void validateRequiredFields(Id eventTypeId, Map<Id, String> responses) {
        for (Booking_Field__c field : [
            SELECT Id, Name
            FROM Booking_Field__c
            WHERE Event_Type__c = :eventTypeId AND Is_Required__c = true
            WITH USER_MODE
        ]) {
            String value = responses != null ? responses.get(field.Id) : null;
            if (String.isBlank(value)) {
                throw new SchedulingException(
                    'REQUIRED_FIELD',
                    'Required field missing: ' + field.Name
                );
            }
        }
    }

    private static List<String> parseOptions(String optionsText) {
        List<String> options = new List<String>();
        if (String.isBlank(optionsText)) {
            return options;
        }
        for (String line : optionsText.split('\n')) {
            String trimmed = line.trim();
            if (String.isNotBlank(trimmed)) {
                options.add(trimmed);
            }
        }
        return options;
    }
}
