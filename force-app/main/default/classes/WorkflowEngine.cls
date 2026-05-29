public with sharing class WorkflowEngine {

    public static void executeWorkflows(String triggerEvent, List<Id> bookingIds) {
        if (bookingIds == null || bookingIds.isEmpty()) return;

        List<Booking__c> bookings = [
            SELECT Id, Event_Type__c, Host__c, Host__r.Email, Host__r.Name,
                   Booker_Email__c, Booker_Name__c, Title__c,
                   Start_DateTime__c, End_DateTime__c, Location__c
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];

        Set<Id> eventTypeIds = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Event_Type__c != null) eventTypeIds.add(b.Event_Type__c);
        }

        List<Workflow__c> workflows = [
            SELECT Id, Trigger_Event__c, Event_Type__c,
                (SELECT Id, Action_Type__c, Recipient__c, Template__c, Webhook_URL__c, Sort_Order__c
                 FROM Steps__r
                 ORDER BY Sort_Order__c ASC)
            FROM Workflow__c
            WHERE Is_Active__c = true
                AND Trigger_Event__c = :triggerEvent
                AND (Event_Type__c = null OR Event_Type__c IN :eventTypeIds)
            WITH USER_MODE
        ];

        for (Booking__c booking : bookings) {
            for (Workflow__c workflow : workflows) {
                if (workflow.Event_Type__c != null && workflow.Event_Type__c != booking.Event_Type__c) {
                    continue;
                }
                executeSteps(workflow.Steps__r, booking);
            }
        }
    }

    public static void scheduleReminderWorkflows() {
        List<Workflow__c> reminderWorkflows = [
            SELECT Id, Trigger_Event__c, Time_Offset_Minutes__c, Event_Type__c,
                (SELECT Id, Action_Type__c, Recipient__c, Template__c, Webhook_URL__c
                 FROM Steps__r
                 ORDER BY Sort_Order__c ASC)
            FROM Workflow__c
            WHERE Is_Active__c = true
                AND Trigger_Event__c IN ('Before_Event', 'After_Event')
                AND Time_Offset_Minutes__c != null
            WITH USER_MODE
        ];

        for (Workflow__c workflow : reminderWorkflows) {
            Integer offsetMinutes = (Integer) workflow.Time_Offset_Minutes__c;
            Datetime targetTime;

            if (workflow.Trigger_Event__c == 'Before_Event') {
                targetTime = Datetime.now().addMinutes(offsetMinutes);
                List<Booking__c> upcomingBookings = [
                    SELECT Id, Host__c, Host__r.Email, Host__r.Name,
                           Booker_Email__c, Booker_Name__c, Title__c,
                           Start_DateTime__c, End_DateTime__c, Location__c, Event_Type__c
                    FROM Booking__c
                    WHERE Status__c = 'Accepted'
                        AND Start_DateTime__c >= :Datetime.now()
                        AND Start_DateTime__c <= :targetTime
                    WITH USER_MODE
                    LIMIT 100
                ];
                for (Booking__c booking : upcomingBookings) {
                    if (workflow.Event_Type__c == null || workflow.Event_Type__c == booking.Event_Type__c) {
                        executeSteps(workflow.Steps__r, booking);
                    }
                }
            }
        }
    }

    private static void executeSteps(List<Workflow_Step__c> steps, Booking__c booking) {
        for (Workflow_Step__c step : steps) {
            try {
                switch on step.Action_Type__c {
                    when 'Email' {
                        sendEmailStep(step, booking);
                    }
                    when 'SMS' {
                        sendSmsStep(step, booking);
                    }
                    when 'Webhook' {
                        sendWebhookStep(step, booking);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Workflow step failed: ' + step.Id + ' - ' + e.getMessage());
            }
        }
    }

    private static void sendEmailStep(Workflow_Step__c step, Booking__c booking) {
        List<String> recipients = getRecipientEmails(step.Recipient__c, booking);
        String body = mergeTemplate(step.Template__c, booking);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (String recipient : recipients) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ recipient });
            email.setSubject('Reminder: ' + booking.Title__c);
            email.setHtmlBody(body);
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails, false);
        }
    }

    private static void sendSmsStep(Workflow_Step__c step, Booking__c booking) {
        System.debug(LoggingLevel.INFO, 'SMS step placeholder - integrate with Twilio/MessageBird Named Credential');
    }

    private static void sendWebhookStep(Workflow_Step__c step, Booking__c booking) {
        if (String.isBlank(step.Webhook_URL__c)) return;

        String payload = WebhookService.buildBookingPayload(booking.Id);
        WebhookService.fireWebhooks('workflow.step', payload);
    }

    private static List<String> getRecipientEmails(String recipient, Booking__c booking) {
        List<String> emails = new List<String>();
        if (recipient == 'Host' || recipient == 'Both') {
            if (booking.Host__r != null && String.isNotBlank(booking.Host__r.Email)) {
                emails.add(booking.Host__r.Email);
            }
        }
        if (recipient == 'Attendee' || recipient == 'Both') {
            if (String.isNotBlank(booking.Booker_Email__c)) {
                emails.add(booking.Booker_Email__c);
            }
        }
        return emails;
    }

    private static String mergeTemplate(String template, Booking__c booking) {
        if (String.isBlank(template)) return '';
        String result = template;
        result = result.replace('{booking.title}', booking.Title__c != null ? booking.Title__c : '');
        result = result.replace('{booking.start}', booking.Start_DateTime__c != null ? booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') : '');
        result = result.replace('{booking.end}', booking.End_DateTime__c != null ? booking.End_DateTime__c.format('h:mm a') : '');
        result = result.replace('{booking.location}', booking.Location__c != null ? booking.Location__c : '');
        result = result.replace('{host.name}', booking.Host__r != null && booking.Host__r.Name != null ? booking.Host__r.Name : '');
        result = result.replace('{host.email}', booking.Host__r != null && booking.Host__r.Email != null ? booking.Host__r.Email : '');
        result = result.replace('{attendee.name}', booking.Booker_Name__c != null ? booking.Booker_Name__c : '');
        result = result.replace('{attendee.email}', booking.Booker_Email__c != null ? booking.Booker_Email__c : '');
        return result;
    }
}
