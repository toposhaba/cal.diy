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

    private static String generateUID() {
        Blob randomBytes = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' + hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }
}
