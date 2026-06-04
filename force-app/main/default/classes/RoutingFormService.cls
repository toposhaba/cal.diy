public with sharing class RoutingFormService {

    public class FormFieldInfo {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public List<String> options { get; set; }
    }

    public class RoutingResult {
        @AuraEnabled public Id eventTypeId { get; set; }
        @AuraEnabled public String eventTypeName { get; set; }
    }

    public static List<Routing_Form__c> getActiveForms(Id ownerUserId) {
        Id targetUser = ownerUserId != null ? ownerUserId : UserInfo.getUserId();
        return [
            SELECT Id, Name, Description__c
            FROM Routing_Form__c
            WHERE Owner_User__c = :targetUser
                OR (Owner_User__c = null AND OwnerId = :targetUser)
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    public static List<FormFieldInfo> getFormFieldInfo(Id routingFormId) {
        List<FormFieldInfo> fields = new List<FormFieldInfo>();
        for (Routing_Form_Field__c field : getFormFields(routingFormId)) {
            FormFieldInfo info = new FormFieldInfo();
            info.id = field.Id;
            info.name = field.Name;
            info.fieldType = field.Field_Type__c;
            info.options = parseOptions(field.Options__c);
            fields.add(info);
        }
        return fields;
    }

    public static RoutingResult evaluateForm(Id routingFormId, Map<Id, String> fieldResponses) {
        Id eventTypeId = resolveRoute(routingFormId, fieldResponses);
        List<Event_Type__c> eventTypes = [
            SELECT Name
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        RoutingResult result = new RoutingResult();
        result.eventTypeId = eventTypeId;
        result.eventTypeName = eventTypes.isEmpty() ? null : eventTypes[0].Name;
        return result;
    }

    public static Id resolveRoute(Id routingFormId, Map<Id, String> fieldResponses) {
        Routing_Form__c form = [
            SELECT Id,
                (SELECT Id, Condition__c, Target_Event_Type__c
                 FROM Routes__r)
            FROM Routing_Form__c
            WHERE Id = :routingFormId
            WITH USER_MODE
            LIMIT 1
        ];

        if (form == null) {
            throw new SchedulingException('FORM_NOT_FOUND', 'Routing form not found');
        }

        for (Routing_Form_Route__c route : form.Routes__r) {
            if (evaluateCondition(route.Condition__c, fieldResponses)) {
                return route.Target_Event_Type__c;
            }
        }

        throw new SchedulingException('NO_MATCHING_ROUTE', 'No routing rule matched the provided answers');
    }

    public static List<Routing_Form_Field__c> getFormFields(Id routingFormId) {
        return [
            SELECT Id, Name, Field_Type__c, Options__c
            FROM Routing_Form_Field__c
            WHERE Routing_Form__c = :routingFormId
            WITH USER_MODE
            ORDER BY Name ASC
        ];
    }

    private static Boolean evaluateCondition(String conditionJson, Map<Id, String> fieldResponses) {
        if (String.isBlank(conditionJson)) return true;

        Map<String, Object> condition = (Map<String, Object>) JSON.deserializeUntyped(conditionJson);
        String fieldId = (String) condition.get('fieldId');
        String operator = (String) condition.get('operator');
        String expectedValue = (String) condition.get('value');

        if (String.isBlank(fieldId)) {
            return false;
        }

        Id fieldIdKey = (Id) fieldId;
        if (!fieldResponses.containsKey(fieldIdKey)) {
            return false;
        }

        String actualValue = fieldResponses.get(fieldIdKey);

        switch on operator {
            when 'equals' {
                return actualValue == expectedValue;
            }
            when 'not_equals' {
                return actualValue != expectedValue;
            }
            when 'contains' {
                return actualValue != null && actualValue.contains(expectedValue);
            }
            when 'starts_with' {
                return actualValue != null && actualValue.startsWith(expectedValue);
            }
            when else {
                return actualValue == expectedValue;
            }
        }
    }

    private static List<String> parseOptions(String optionsValue) {
        List<String> options = new List<String>();
        if (String.isBlank(optionsValue)) {
            return options;
        }

        String trimmed = optionsValue.trim();
        if (trimmed.startsWith('[')) {
            List<Object> parsed = (List<Object>) JSON.deserializeUntyped(trimmed);
            for (Object item : parsed) {
                options.add(String.valueOf(item));
            }
            return options;
        }

        for (String option : trimmed.split('\n')) {
            if (String.isNotBlank(option)) {
                options.add(option.trim());
            }
        }
        return options;
    }
}
