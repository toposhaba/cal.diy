public with sharing class RoutingFormWizardController {

    public class WizardInitData {
        @AuraEnabled public Id currentUserId { get; set; }
        @AuraEnabled public String currentUserName { get; set; }
        @AuraEnabled public List<EventTypeOption> eventTypes { get; set; }
        @AuraEnabled public List<Routing_Form__c> existingForms { get; set; }
    }

    public class EventTypeOption {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
    }

    public class WizardFormData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Id ownerUserId { get; set; }
        @AuraEnabled public String ownerUserName { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public List<WizardFieldData> fields { get; set; }
        @AuraEnabled public List<WizardRouteData> routes { get; set; }
    }

    public class WizardFieldData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String clientKey { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public String options { get; set; }
        @AuraEnabled public Boolean isRequired { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }
    }

    public class WizardRouteData {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id targetEventTypeId { get; set; }
        @AuraEnabled public String targetEventTypeName { get; set; }
        @AuraEnabled public String conditionFieldId { get; set; }
        @AuraEnabled public String conditionClientKey { get; set; }
        @AuraEnabled public String conditionOperator { get; set; }
        @AuraEnabled public String conditionValue { get; set; }
    }

    public class WizardFieldInput {
        @AuraEnabled public String clientKey { get; set; }
        @AuraEnabled public Id fieldId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String fieldType { get; set; }
        @AuraEnabled public String options { get; set; }
        @AuraEnabled public Boolean isRequired { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }
    }

    public class WizardRouteInput {
        @AuraEnabled public Id routeId { get; set; }
        @AuraEnabled public Id targetEventTypeId { get; set; }
        @AuraEnabled public String conditionFieldId { get; set; }
        @AuraEnabled public String conditionClientKey { get; set; }
        @AuraEnabled public String conditionOperator { get; set; }
        @AuraEnabled public String conditionValue { get; set; }
    }

    public class WizardSaveResult {
        @AuraEnabled public Id formId { get; set; }
        @AuraEnabled public String formName { get; set; }
        @AuraEnabled public Id ownerUserId { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static WizardInitData getWizardInitData(Id hostUserId) {
        Id targetUser = hostUserId != null ? hostUserId : UserInfo.getUserId();
        User currentUser = [
            SELECT Id, Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        WizardInitData data = new WizardInitData();
        data.currentUserId = currentUser.Id;
        data.currentUserName = currentUser.Name;
        data.existingForms = [
            SELECT Id, Name, Description__c, Is_Active__c
            FROM Routing_Form__c
            WHERE Owner_User__c = :UserInfo.getUserId()
                OR (Owner_User__c = null AND OwnerId = :UserInfo.getUserId())
            WITH USER_MODE
            ORDER BY Name ASC
        ];
        data.eventTypes = new List<EventTypeOption>();

        for (Event_Type__c eventType : SchedulingController.getActiveEventTypes(targetUser)) {
            EventTypeOption option = new EventTypeOption();
            option.id = eventType.Id;
            option.name = eventType.Name;
            data.eventTypes.add(option);
        }
        return data;
    }

    @AuraEnabled(cacheable=true)
    public static WizardFormData getFormForWizard(Id formId) {
        assertRoutingFormOwnership(formId);

        Routing_Form__c form = [
            SELECT Id, Name, Description__c, Owner_User__c, Owner_User__r.Name, Is_Active__c,
                (SELECT Id, Name, Field_Type__c, Options__c, Is_Required__c, Sort_Order__c
                 FROM Fields__r ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC),
                (SELECT Id, Condition__c, Target_Event_Type__c, Target_Event_Type__r.Name
                 FROM Routes__r ORDER BY CreatedDate ASC)
            FROM Routing_Form__c
            WHERE Id = :formId
            WITH USER_MODE
            LIMIT 1
        ];

        WizardFormData data = new WizardFormData();
        data.id = form.Id;
        data.name = form.Name;
        data.description = form.Description__c;
        data.ownerUserId = form.Owner_User__c != null ? form.Owner_User__c : UserInfo.getUserId();
        data.ownerUserName = form.Owner_User__r != null ? form.Owner_User__r.Name : null;
        data.isActive = form.Is_Active__c != false;
        data.fields = new List<WizardFieldData>();
        data.routes = new List<WizardRouteData>();

        Integer sortIndex = 0;
        for (Routing_Form_Field__c field : form.Fields__r) {
            WizardFieldData fieldData = new WizardFieldData();
            fieldData.id = field.Id;
            fieldData.clientKey = String.valueOf(field.Id);
            fieldData.name = field.Name;
            fieldData.fieldType = field.Field_Type__c;
            fieldData.options = field.Options__c;
            fieldData.isRequired = field.Is_Required__c != false;
            fieldData.sortOrder = field.Sort_Order__c != null
                ? Integer.valueOf(field.Sort_Order__c)
                : sortIndex;
            data.fields.add(fieldData);
            sortIndex++;
        }

        for (Routing_Form_Route__c route : form.Routes__r) {
            WizardRouteData routeData = new WizardRouteData();
            routeData.id = route.Id;
            routeData.targetEventTypeId = route.Target_Event_Type__c;
            routeData.targetEventTypeName = route.Target_Event_Type__r != null
                ? route.Target_Event_Type__r.Name
                : null;
            parseRouteCondition(route.Condition__c, routeData);
            data.routes.add(routeData);
        }

        return data;
    }

    @AuraEnabled
    public static WizardSaveResult saveRoutingFormWizard(
        Id formId,
        String name,
        String description,
        Id ownerUserId,
        Boolean isActive,
        List<WizardFieldInput> fields,
        List<WizardRouteInput> routes
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException('Form name is required');
        }
        if (fields == null || fields.isEmpty()) {
            throw new AuraHandledException('At least one question is required');
        }
        if (routes == null || routes.isEmpty()) {
            throw new AuraHandledException('At least one route is required');
        }

        Id resolvedOwner = ownerUserId != null ? ownerUserId : UserInfo.getUserId();
        Boolean resolvedActive = isActive != false;

        Routing_Form__c form;
        if (formId != null) {
            assertRoutingFormOwnership(formId);
            form = [
                SELECT Id, Name, Description__c, Owner_User__c, Is_Active__c
                FROM Routing_Form__c
                WHERE Id = :formId
                WITH USER_MODE
                LIMIT 1
            ];
            form.Name = name;
            form.Description__c = description;
            form.Owner_User__c = resolvedOwner;
            form.Is_Active__c = resolvedActive;
            update form;
        } else {
            form = new Routing_Form__c(
                Name = name,
                Description__c = description,
                Owner_User__c = resolvedOwner,
                Is_Active__c = resolvedActive
            );
            insert form;
        }

        Map<String, Id> clientKeyToFieldId = new Map<String, Id>();
        Set<Id> retainedFieldIds = new Set<Id>();
        List<Routing_Form_Field__c> fieldsToUpsert = new List<Routing_Form_Field__c>();
        Integer fieldIndex = 0;

        for (WizardFieldInput fieldInput : fields) {
            if (String.isBlank(fieldInput.name) || String.isBlank(fieldInput.fieldType)) {
                throw new AuraHandledException('Each question needs a label and type');
            }

            Routing_Form_Field__c fieldRecord;
            if (fieldInput.fieldId != null) {
                fieldRecord = new Routing_Form_Field__c(
                    Id = fieldInput.fieldId,
                    Routing_Form__c = form.Id,
                    Name = fieldInput.name,
                    Field_Type__c = fieldInput.fieldType,
                    Options__c = fieldInput.options,
                    Is_Required__c = fieldInput.isRequired != false,
                    Sort_Order__c = fieldInput.sortOrder != null ? fieldInput.sortOrder : fieldIndex
                );
                retainedFieldIds.add(fieldInput.fieldId);
            } else {
                fieldRecord = new Routing_Form_Field__c(
                    Routing_Form__c = form.Id,
                    Name = fieldInput.name,
                    Field_Type__c = fieldInput.fieldType,
                    Options__c = fieldInput.options,
                    Is_Required__c = fieldInput.isRequired != false,
                    Sort_Order__c = fieldInput.sortOrder != null ? fieldInput.sortOrder : fieldIndex
                );
            }
            fieldsToUpsert.add(fieldRecord);
            fieldIndex++;
        }

        upsert fieldsToUpsert;

        for (Integer i = 0; i < fields.size(); i++) {
            WizardFieldInput fieldInput = fields[i];
            Routing_Form_Field__c savedField = fieldsToUpsert[i];
            if (String.isNotBlank(fieldInput.clientKey)) {
                clientKeyToFieldId.put(fieldInput.clientKey, savedField.Id);
            }
            clientKeyToFieldId.put(String.valueOf(savedField.Id), savedField.Id);
            retainedFieldIds.add(savedField.Id);
        }

        List<Routing_Form_Field__c> existingFields = [
            SELECT Id
            FROM Routing_Form_Field__c
            WHERE Routing_Form__c = :form.Id
            WITH USER_MODE
        ];
        List<Routing_Form_Field__c> fieldsToDelete = new List<Routing_Form_Field__c>();
        for (Routing_Form_Field__c existingField : existingFields) {
            if (!retainedFieldIds.contains(existingField.Id)) {
                fieldsToDelete.add(existingField);
            }
        }
        if (!fieldsToDelete.isEmpty()) {
            delete fieldsToDelete;
        }

        Set<Id> retainedRouteIds = new Set<Id>();
        List<Routing_Form_Route__c> routesToUpsert = new List<Routing_Form_Route__c>();

        for (WizardRouteInput routeInput : routes) {
            if (routeInput.targetEventTypeId == null) {
                throw new AuraHandledException('Each route needs a target event type');
            }

            Map<String, String> condition = buildCondition(routeInput, clientKeyToFieldId);
            Routing_Form_Route__c routeRecord;
            if (routeInput.routeId != null) {
                routeRecord = new Routing_Form_Route__c(
                    Id = routeInput.routeId,
                    Routing_Form__c = form.Id,
                    Target_Event_Type__c = routeInput.targetEventTypeId,
                    Condition__c = condition.isEmpty() ? null : JSON.serialize(condition)
                );
                retainedRouteIds.add(routeInput.routeId);
            } else {
                routeRecord = new Routing_Form_Route__c(
                    Routing_Form__c = form.Id,
                    Target_Event_Type__c = routeInput.targetEventTypeId,
                    Condition__c = condition.isEmpty() ? null : JSON.serialize(condition)
                );
            }
            routesToUpsert.add(routeRecord);
        }

        upsert routesToUpsert;
        for (Routing_Form_Route__c savedRoute : routesToUpsert) {
            retainedRouteIds.add(savedRoute.Id);
        }

        List<Routing_Form_Route__c> existingRoutes = [
            SELECT Id
            FROM Routing_Form_Route__c
            WHERE Routing_Form__c = :form.Id
            WITH USER_MODE
        ];
        List<Routing_Form_Route__c> routesToDelete = new List<Routing_Form_Route__c>();
        for (Routing_Form_Route__c existingRoute : existingRoutes) {
            if (!retainedRouteIds.contains(existingRoute.Id)) {
                routesToDelete.add(existingRoute);
            }
        }
        if (!routesToDelete.isEmpty()) {
            delete routesToDelete;
        }

        WizardSaveResult result = new WizardSaveResult();
        result.formId = form.Id;
        result.formName = form.Name;
        result.ownerUserId = resolvedOwner;
        return result;
    }

    private static Map<String, String> buildCondition(
        WizardRouteInput routeInput,
        Map<String, Id> clientKeyToFieldId
    ) {
        Map<String, String> condition = new Map<String, String>();
        Id fieldId;

        if (String.isNotBlank(routeInput.conditionFieldId)) {
            fieldId = (Id) routeInput.conditionFieldId;
        } else if (String.isNotBlank(routeInput.conditionClientKey)) {
            fieldId = clientKeyToFieldId.get(routeInput.conditionClientKey);
        }

        if (fieldId == null) {
            return condition;
        }

        condition.put('fieldId', String.valueOf(fieldId));
        condition.put('operator', String.isNotBlank(routeInput.conditionOperator)
            ? routeInput.conditionOperator
            : 'equals');
        condition.put('value', routeInput.conditionValue != null ? routeInput.conditionValue : '');
        return condition;
    }

    private static void parseRouteCondition(String conditionJson, WizardRouteData routeData) {
        if (String.isBlank(conditionJson)) {
            return;
        }

        Map<String, Object> condition = (Map<String, Object>) JSON.deserializeUntyped(conditionJson);
        routeData.conditionFieldId = (String) condition.get('fieldId');
        routeData.conditionOperator = (String) condition.get('operator');
        routeData.conditionValue = (String) condition.get('value');
    }

    private static void assertRoutingFormOwnership(Id formId) {
        List<Routing_Form__c> forms = [
            SELECT Id
            FROM Routing_Form__c
            WHERE Id = :formId
                AND (Owner_User__c = :UserInfo.getUserId()
                    OR (Owner_User__c = null AND OwnerId = :UserInfo.getUserId()))
            WITH USER_MODE
            LIMIT 1
        ];
        if (forms.isEmpty()) {
            throw new AuraHandledException('Routing form not found or access denied');
        }
    }
}
