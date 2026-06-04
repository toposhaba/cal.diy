@IsTest
private class RoutingFormServiceTest {

    @IsTest
    static void testResolveRouteEquals() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c salesEvent = SchedulingTestDataFactory.createEventType(testUser.Id, 'Sales Call', 30);
            Event_Type__c supportEvent = SchedulingTestDataFactory.createEventType(testUser.Id, 'Support Call', 30);
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'Lead Router');
            Routing_Form_Field__c topicField = SchedulingTestDataFactory.createRoutingFormField(
                form.Id, 'Topic', 'Select', 'Sales\nSupport'
            );

            String condition = '{"fieldId":"' + topicField.Id + '","operator":"equals","value":"Sales"}';
            SchedulingTestDataFactory.createRoutingFormRoute(form.Id, salesEvent.Id, condition);
            SchedulingTestDataFactory.createRoutingFormRoute(form.Id, supportEvent.Id, null);

            Map<Id, String> responses = new Map<Id, String>{
                topicField.Id => 'Sales'
            };

            Test.startTest();
            Id routeId = RoutingFormService.resolveRoute(form.Id, responses);
            RoutingFormService.RoutingResult result = RoutingFormService.evaluateForm(form.Id, responses);
            Test.stopTest();

            System.assertEquals(salesEvent.Id, routeId);
            System.assertEquals('Sales Call', result.eventTypeName);
        }
    }

    @IsTest
    static void testResolveRouteContains() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Enterprise', 60);
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'Company Router');
            Routing_Form_Field__c companyField = SchedulingTestDataFactory.createRoutingFormField(
                form.Id, 'Company', 'Text', null
            );

            String condition = '{"fieldId":"' + companyField.Id + '","operator":"contains","value":"Acme"}';
            SchedulingTestDataFactory.createRoutingFormRoute(form.Id, eventType.Id, condition);

            Map<Id, String> responses = new Map<Id, String>{
                companyField.Id => 'Acme Corporation'
            };

            Test.startTest();
            Id routeId = RoutingFormService.resolveRoute(form.Id, responses);
            Test.stopTest();

            System.assertEquals(eventType.Id, routeId);
        }
    }

    @IsTest
    static void testNoMatchingRoute() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Event_Type__c eventType = SchedulingTestDataFactory.createEventType(testUser.Id, 'Fallback', 30);
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'Strict Router');
            Routing_Form_Field__c roleField = SchedulingTestDataFactory.createRoutingFormField(
                form.Id, 'Role', 'Select', 'Admin'
            );

            String condition = '{"fieldId":"' + roleField.Id + '","operator":"equals","value":"Admin"}';
            SchedulingTestDataFactory.createRoutingFormRoute(form.Id, eventType.Id, condition);

            Map<Id, String> responses = new Map<Id, String>{
                roleField.Id => 'Guest'
            };

            Test.startTest();
            try {
                RoutingFormService.resolveRoute(form.Id, responses);
                System.assert(false, 'Expected no matching route');
            } catch (SchedulingException e) {
                System.assertEquals('NO_MATCHING_ROUTE', e.getErrorCode());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetFormFieldInfo() {
        User testUser = SchedulingTestDataFactory.createTestUser();

        System.runAs(testUser) {
            Routing_Form__c form = SchedulingTestDataFactory.createRoutingForm(testUser.Id, 'Field Info');
            SchedulingTestDataFactory.createRoutingFormField(form.Id, 'Department', 'Select', '["Sales","Support"]');

            Test.startTest();
            List<RoutingFormService.FormFieldInfo> fields = RoutingFormService.getFormFieldInfo(form.Id);
            List<Routing_Form__c> forms = RoutingFormService.getActiveForms(testUser.Id);
            Test.stopTest();

            System.assertEquals(1, fields.size());
            System.assertEquals(2, fields[0].options.size());
            System.assertEquals(1, forms.size());
        }
    }
}
