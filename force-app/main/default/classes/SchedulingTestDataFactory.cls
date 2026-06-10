@IsTest
public class SchedulingTestDataFactory {

    public static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueStr = String.valueOf(Datetime.now().getTime());
        User u = new User(
            FirstName = 'Test',
            LastName = 'Host',
            Email = 'testhost' + uniqueStr + '@example.com',
            Username = 'testhost' + uniqueStr + '@example.com.test',
            Alias = 'thost',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name IN ('Scheduling_Host', 'Scheduling_Admin')
        ];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : permSets) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = u.Id,
                PermissionSetId = ps.Id
            ));
        }
        insert assignments;

        return u;
    }

    public static User createBookerUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueStr = String.valueOf(Datetime.now().getTime());
        User u = new User(
            FirstName = 'Test',
            LastName = 'Booker',
            Email = 'testbooker' + uniqueStr + '@example.com',
            Username = 'testbooker' + uniqueStr + '@example.com.test',
            Alias = 'tbkr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        PermissionSet bookerPermSet = [
            SELECT Id FROM PermissionSet WHERE Name = 'Scheduling_Booker' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = bookerPermSet.Id
        );

        return u;
    }

    public static Schedule__c createSchedule(Id userId, String name, Boolean isDefault) {
        Schedule__c schedule = new Schedule__c(
            Name = name,
            Owner_User__c = userId,
            Time_Zone__c = 'America/New_York',
            Is_Default__c = isDefault
        );
        insert schedule;
        return schedule;
    }

    public static Availability__c createWorkingHours(Id scheduleId, String days, Time startTime, Time endTime) {
        Availability__c avail = new Availability__c(
            Schedule__c = scheduleId,
            Record_Type__c = 'Working_Hours',
            Days__c = days,
            Start_Time__c = startTime,
            End_Time__c = endTime
        );
        insert avail;
        return avail;
    }

    public static Availability__c createDateOverride(Id scheduleId, Date overrideDate, Time startTime, Time endTime) {
        Availability__c avail = new Availability__c(
            Schedule__c = scheduleId,
            Record_Type__c = 'Date_Override',
            Days__c = null,
            Start_Time__c = startTime,
            End_Time__c = endTime,
            Override_Date__c = overrideDate
        );
        insert avail;
        return avail;
    }

    public static Event_Type__c createEventType(Id userId, String name, Integer durationMinutes) {
        Event_Type__c et = new Event_Type__c(
            Name = name,
            Slug__c = name.toLowerCase().replaceAll(' ', '-') + '-' + String.valueOf(Datetime.now().getTime()),
            Owner_User__c = userId,
            Duration_Minutes__c = durationMinutes,
            Min_Booking_Notice_Minutes__c = 60,
            Buffer_Before_Minutes__c = 0,
            Buffer_After_Minutes__c = 0,
            Is_Active__c = true,
            Requires_Confirmation__c = false
        );
        insert et;
        return et;
    }

    public static Event_Type__c createEventTypeWithSchedule(Id userId, Id scheduleId, String name, Integer durationMinutes) {
        Event_Type__c et = new Event_Type__c(
            Name = name,
            Slug__c = name.toLowerCase().replaceAll(' ', '-') + '-' + String.valueOf(Datetime.now().getTime()),
            Owner_User__c = userId,
            Schedule__c = scheduleId,
            Duration_Minutes__c = durationMinutes,
            Min_Booking_Notice_Minutes__c = 60,
            Buffer_Before_Minutes__c = 5,
            Buffer_After_Minutes__c = 5,
            Is_Active__c = true,
            Requires_Confirmation__c = false
        );
        insert et;
        return et;
    }

    public static Booking__c createBooking(Id eventTypeId, Id hostId, Datetime startDt, Datetime endDt) {
        Booking__c booking = new Booking__c(
            UID__c = generateUID(),
            Event_Type__c = eventTypeId,
            Host__c = hostId,
            Title__c = 'Test Booking',
            Start_DateTime__c = startDt,
            End_DateTime__c = endDt,
            Status__c = 'Accepted',
            Booker_Email__c = 'booker@example.com',
            Booker_Name__c = 'Test Booker'
        );
        insert booking;
        return booking;
    }

    public static Calendar_Connection__c createCalendarConnection(Id userId, String provider, Boolean pushEvents) {
        Calendar_Connection__c connection = new Calendar_Connection__c(
            Name = provider + ' Connection',
            Owner_User__c = userId,
            Provider__c = provider,
            Is_Active__c = true,
            Push_Events_To__c = pushEvents,
            Check_For_Conflicts__c = true
        );
        insert connection;
        return connection;
    }

    public static Webhook__c createWebhook(Id userId, String eventName, String url) {
        Webhook__c webhook = new Webhook__c(
            Name = 'Test Webhook',
            Owner_User__c = userId,
            URL__c = url,
            Events__c = eventName,
            Is_Active__c = true
        );
        insert webhook;
        return webhook;
    }

    public static Workflow__c createWorkflow(String triggerEvent, Id eventTypeId, String recipient, String template) {
        Workflow__c workflow = new Workflow__c(
            Name = 'Test Workflow',
            Trigger_Event__c = triggerEvent,
            Is_Active__c = true,
            Event_Type__c = eventTypeId
        );
        insert workflow;

        insert new Workflow_Step__c(
            Workflow__c = workflow.Id,
            Action_Type__c = 'Email',
            Recipient__c = recipient,
            Template__c = template,
            Sort_Order__c = 1
        );

        return workflow;
    }

    public static Team__c createTeam(Id userId, String name) {
        Team__c team = new Team__c(
            Name = name,
            Slug__c = name.toLowerCase().replaceAll(' ', '-') + '-' + String.valueOf(Datetime.now().getTime()),
            Time_Zone__c = 'America/New_York'
        );
        insert team;

        insert new Team_Member__c(
            Team__c = team.Id,
            User__c = userId,
            Role__c = 'Admin'
        );

        return team;
    }

    public static Event_Type_Host__c createEventTypeHost(Id eventTypeId, Id userId, Decimal weight, Boolean isFixed) {
        Event_Type_Host__c host = new Event_Type_Host__c(
            Event_Type__c = eventTypeId,
            User__c = userId,
            Weight__c = weight,
            Is_Fixed__c = isFixed,
            Priority__c = 1
        );
        insert host;
        return host;
    }

    public static Event_Type__c createTeamEventType(
        Id userId, String name, Integer durationMinutes, String schedulingType, List<Id> hostUserIds
    ) {
        Event_Type__c eventType = createEventType(userId, name, durationMinutes);
        eventType.Scheduling_Type__c = schedulingType;
        update eventType;

        List<Event_Type_Host__c> hosts = new List<Event_Type_Host__c>();
        for (Id hostUserId : hostUserIds) {
            hosts.add(new Event_Type_Host__c(
                Event_Type__c = eventType.Id,
                User__c = hostUserId,
                Priority__c = 1,
                Weight__c = 100,
                Is_Fixed__c = schedulingType == 'Managed'
            ));
        }
        insert hosts;
        return eventType;
    }

    public static Out_of_Office__c createOutOfOffice(Id userId, Date startDate, Date endDate) {
        Out_of_Office__c ooo = new Out_of_Office__c(
            User__c = userId,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Reason__c = 'Out of office'
        );
        insert ooo;
        return ooo;
    }

    public static Routing_Form__c createRoutingForm(Id userId, String name) {
        Routing_Form__c form = new Routing_Form__c(
            Name = name,
            Owner_User__c = userId,
            Description__c = 'Test routing form'
        );
        insert form;
        return form;
    }

    public static Routing_Form_Field__c createRoutingFormField(
        Id formId, String name, String fieldType, String options
    ) {
        Routing_Form_Field__c field = new Routing_Form_Field__c(
            Routing_Form__c = formId,
            Name = name,
            Field_Type__c = fieldType,
            Options__c = options
        );
        insert field;
        return field;
    }

    public static Routing_Form_Route__c createRoutingFormRoute(
        Id formId, Id eventTypeId, String conditionJson
    ) {
        Routing_Form_Route__c route = new Routing_Form_Route__c(
            Routing_Form__c = formId,
            Target_Event_Type__c = eventTypeId,
            Condition__c = conditionJson
        );
        insert route;
        return route;
    }

    private static String generateUID() {
        Blob randomBytes = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' + hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }
}
