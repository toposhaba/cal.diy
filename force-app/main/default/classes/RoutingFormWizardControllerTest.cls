@IsTest
private class RoutingFormWizardControllerTest {

    @IsTest
    static void testWizardInitAndSave() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Wizard Event', 30);

            Test.startTest();
            RoutingFormWizardController.WizardInitData initData =
                RoutingFormWizardController.getWizardInitData(testUser.Id);
            System.assertNotEquals(null, initData.currentUserId);
            System.assertEquals(1, initData.eventTypes.size());

            List<RoutingFormWizardController.WizardFieldInput> fields =
                new List<RoutingFormWizardController.WizardFieldInput>();
            RoutingFormWizardController.WizardFieldInput fieldInput =
                new RoutingFormWizardController.WizardFieldInput();
            fieldInput.clientKey = 'field-1';
            fieldInput.name = 'Company Size';
            fieldInput.fieldType = 'Select';
            fieldInput.options = 'Small\nLarge';
            fieldInput.isRequired = true;
            fieldInput.sortOrder = 0;
            fields.add(fieldInput);

            List<RoutingFormWizardController.WizardRouteInput> routes =
                new List<RoutingFormWizardController.WizardRouteInput>();
            RoutingFormWizardController.WizardRouteInput routeInput =
                new RoutingFormWizardController.WizardRouteInput();
            routeInput.targetEventTypeId = eventType.Id;
            routeInput.conditionClientKey = 'field-1';
            routeInput.conditionOperator = 'equals';
            routeInput.conditionValue = 'Large';
            routes.add(routeInput);

            RoutingFormWizardController.WizardSaveResult saveResult =
                RoutingFormWizardController.saveRoutingFormWizard(
                    null,
                    'Wizard Form',
                    'Routes by company size',
                    testUser.Id,
                    true,
                    fields,
                    routes
                );
            Test.stopTest();

            System.assertNotEquals(null, saveResult.formId);

            RoutingFormWizardController.WizardFormData formData =
                RoutingFormWizardController.getFormForWizard(saveResult.formId);
            System.assertEquals('Wizard Form', formData.name);
            System.assertEquals(1, formData.fields.size());
            System.assertEquals(1, formData.routes.size());
            System.assertEquals(true, formData.isActive);

            RoutingFormService.RoutingResult evaluation = RoutingFormService.evaluateForm(
                saveResult.formId,
                new Map<Id, String>{ formData.fields[0].id => 'Large' }
            );
            System.assertEquals(eventType.Id, evaluation.eventTypeId);
        }
    }

    @IsTest
    static void testWizardUpdateAndDeactivate() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Update Event', 30);
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'Existing Form');
            Routing_Form_Field__c field = SchedulingTestDataFactory.createRoutingFormField(
                form.Id, 'Role', 'Text', null
            );
            SchedulingTestDataFactory.createRoutingFormRoute(form.Id, eventType.Id, null);

            List<RoutingFormWizardController.WizardFieldInput> fields =
                new List<RoutingFormWizardController.WizardFieldInput>();
            RoutingFormWizardController.WizardFieldInput fieldInput =
                new RoutingFormWizardController.WizardFieldInput();
            fieldInput.fieldId = field.Id;
            fieldInput.clientKey = String.valueOf(field.Id);
            fieldInput.name = 'Updated Role';
            fieldInput.fieldType = 'Text';
            fieldInput.isRequired = false;
            fieldInput.sortOrder = 0;
            fields.add(fieldInput);

            List<RoutingFormWizardController.WizardRouteInput> routes =
                new List<RoutingFormWizardController.WizardRouteInput>();
            RoutingFormWizardController.WizardRouteInput routeInput =
                new RoutingFormWizardController.WizardRouteInput();
            routeInput.targetEventTypeId = eventType.Id;
            routes.add(routeInput);

            Test.startTest();
            RoutingFormWizardController.WizardSaveResult saveResult =
                RoutingFormWizardController.saveRoutingFormWizard(
                    form.Id,
                    'Updated Form',
                    'Updated description',
                    testUser.Id,
                    false,
                    fields,
                    routes
                );
            Test.stopTest();

            RoutingFormWizardController.WizardFormData formData =
                RoutingFormWizardController.getFormForWizard(saveResult.formId);
            System.assertEquals('Updated Form', formData.name);
            System.assertEquals(false, formData.isActive);
            System.assertEquals('Updated Role', formData.fields[0].name);

            List<Routing_Form__c> activeForms = RoutingFormService.getActiveForms(testUser.Id);
            System.assertEquals(0, activeForms.size());
        }
    }

    @IsTest
    static void testWizardValidationErrors() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Boolean threw = false;
            try {
                RoutingFormWizardController.saveRoutingFormWizard(
                    null, '', null, testUser.Id, true, null, null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw);
        }
    }
}
