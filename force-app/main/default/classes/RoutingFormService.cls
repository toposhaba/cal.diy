public with sharing class RoutingFormService {

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

        if (String.isBlank(fieldId) || !fieldResponses.containsKey(fieldId)) {
            return false;
        }

        String actualValue = fieldResponses.get(fieldId);

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
}
