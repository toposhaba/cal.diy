public without sharing class WorkdayScheduleSyncProvider extends HrScheduleSyncProvider {

    private static final List<String> WORKER_ID_KEYS = new List<String>{
        'Worker_ID', 'worker_id', 'Employee_ID', 'employee_id', 'WorkerId'
    };
    private static final List<String> EMAIL_KEYS = new List<String>{
        'Work_Email', 'work_email', 'Email', 'email', 'Primary_Work_Email'
    };
    private static final List<String> SCHEDULE_ID_KEYS = new List<String>{
        'Schedule_ID', 'schedule_id', 'Work_Schedule_ID', 'work_schedule_id', 'Schedule_Pattern_ID'
    };
    private static final List<String> DAY_KEYS = new List<String>{
        'Day_of_Week', 'day_of_week', 'Day', 'day', 'Weekday'
    };
    private static final List<String> START_TIME_KEYS = new List<String>{
        'Start_Time', 'start_time', 'Shift_Start', 'Scheduled_Start', 'In_Time'
    };
    private static final List<String> END_TIME_KEYS = new List<String>{
        'End_Time', 'end_time', 'Shift_End', 'Scheduled_End', 'Out_Time'
    };
    private static final List<String> TIMEZONE_KEYS = new List<String>{
        'Time_Zone', 'time_zone', 'Schedule_Time_Zone', 'Work_Timezone'
    };
    private static final List<String> LOCATION_KEYS = new List<String>{
        'Location', 'location', 'Work_Location', 'Scheduled_Location'
    };

    public WorkdayScheduleSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }

    public override HrSyncService.ProviderSyncResult syncSchedules() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        String reportPath = resolveScheduleReportPath();
        if (String.isBlank(reportPath)) {
            result.errors.add('Schedule report path is not configured');
            return result;
        }

        String responseBody = HrReportClient.fetchReport(config.Named_Credential__c, reportPath);
        List<Object> rows = HrReportClient.parseReportRows(responseBody);
        Map<String, Id> workerMap = HrUserResolver.buildWorkerIdMap(config.Worker_Id_User_Field__c);
        Map<String, Id> emailMap = HrUserResolver.buildEmailMap();
        Map<String, WorkerSchedule> schedulesByKey = new Map<String, WorkerSchedule>();

        for (Object rowObj : rows) {
            ScheduleRow row = parseScheduleRow((Map<String, Object>) rowObj);
            if (row == null) {
                continue;
            }
            Id userId = HrUserResolver.resolveUser(row.workerId, row.email, workerMap, emailMap);
            if (userId == null) {
                result.skipped++;
                continue;
            }
            String scheduleKey = buildScheduleKey(userId, row.scheduleExternalId);
            if (!schedulesByKey.containsKey(scheduleKey)) {
                WorkerSchedule ws = new WorkerSchedule();
                ws.userId = userId;
                ws.externalId = config.Provider_Key__c + ':schedule:' + row.scheduleExternalId;
                ws.timeZone = row.timeZone;
                ws.location = row.location;
                schedulesByKey.put(scheduleKey, ws);
            }
            schedulesByKey.get(scheduleKey).windows.add(row);
        }

        for (WorkerSchedule workerSchedule : schedulesByKey.values()) {
            try {
                syncWorkerSchedule(workerSchedule, result);
            } catch (Exception e) {
                result.errors.add('Schedule sync failed for ' + workerSchedule.externalId + ': ' + e.getMessage());
            }
        }
        return result;
    }

    @TestVisible
    private String resolveScheduleReportPath() {
        if (String.isNotBlank(config.Schedule_Report_Path__c)) {
            return config.Schedule_Report_Path__c;
        }
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Workday_Schedule_Report_Path__c : null;
    }

    @TestVisible
    private ScheduleRow parseScheduleRow(Map<String, Object> row) {
        String workerId = HrReportClient.getStringValue(row, WORKER_ID_KEYS);
        String email = HrReportClient.getStringValue(row, EMAIL_KEYS);
        String dayName = normalizeDayName(HrReportClient.getStringValue(row, DAY_KEYS));
        Time startTime = HrReportClient.parseTimeValue(HrReportClient.getStringValue(row, START_TIME_KEYS));
        Time endTime = HrReportClient.parseTimeValue(HrReportClient.getStringValue(row, END_TIME_KEYS));
        if (String.isBlank(dayName) || startTime == null || endTime == null) {
            return null;
        }
        if (startTime >= endTime) {
            return null;
        }
        ScheduleRow scheduleRow = new ScheduleRow();
        scheduleRow.workerId = workerId;
        scheduleRow.email = email;
        scheduleRow.dayName = dayName;
        scheduleRow.startTime = startTime;
        scheduleRow.endTime = endTime;
        scheduleRow.timeZone = HrReportClient.getStringValue(row, TIMEZONE_KEYS);
        scheduleRow.location = HrReportClient.getStringValue(row, LOCATION_KEYS);
        String scheduleId = HrReportClient.getStringValue(row, SCHEDULE_ID_KEYS);
        scheduleRow.scheduleExternalId = String.isNotBlank(scheduleId) ? scheduleId : workerId;
        scheduleRow.windowExternalId = scheduleRow.scheduleExternalId + ':' + dayName + ':' +
            formatTimeKey(startTime) + '-' + formatTimeKey(endTime);
        return scheduleRow;
    }

    private void syncWorkerSchedule(WorkerSchedule workerSchedule, HrSyncService.ProviderSyncResult result) {
        List<Schedule__c> existing = [
            SELECT Id
            FROM Schedule__c
            WHERE External_Id__c = :workerSchedule.externalId
            LIMIT 1
        ];
        Schedule__c schedule;
        if (existing.isEmpty()) {
            schedule = new Schedule__c(
                Name = config.Provider_Key__c + ' Schedule',
                Owner_User__c = workerSchedule.userId,
                Time_Zone__c = String.isNotBlank(workerSchedule.timeZone)
                    ? workerSchedule.timeZone : 'America/New_York',
                Is_Default__c = true,
                Source__c = config.Provider_Key__c,
                External_Id__c = workerSchedule.externalId
            );
            clearOtherDefaults(workerSchedule.userId);
            insert schedule;
            result.upserted++;
        } else {
            schedule = existing[0];
            schedule.Time_Zone__c = String.isNotBlank(workerSchedule.timeZone)
                ? workerSchedule.timeZone : schedule.Time_Zone__c;
            update schedule;
            result.upserted++;
        }

        List<Availability__c> existingWindows = [
            SELECT Id
            FROM Availability__c
            WHERE Schedule__c = :schedule.Id AND Source__c = :config.Provider_Key__c
        ];
        if (!existingWindows.isEmpty()) {
            delete existingWindows;
        }

        List<Availability__c> newWindows = new List<Availability__c>();
        for (ScheduleRow window : workerSchedule.windows) {
            newWindows.add(new Availability__c(
                Schedule__c = schedule.Id,
                Record_Type__c = 'Working_Hours',
                Days__c = window.dayName,
                Start_Time__c = window.startTime,
                End_Time__c = window.endTime,
                Source__c = config.Provider_Key__c,
                External_Id__c = config.Provider_Key__c + ':' + window.windowExternalId
            ));
        }
        if (!newWindows.isEmpty()) {
            insert newWindows;
            result.upserted += newWindows.size();
        }
    }

    private void clearOtherDefaults(Id userId) {
        List<Schedule__c> defaults = [
            SELECT Id, Is_Default__c
            FROM Schedule__c
            WHERE Owner_User__c = :userId AND Is_Default__c = true
        ];
        for (Schedule__c s : defaults) {
            s.Is_Default__c = false;
        }
        if (!defaults.isEmpty()) {
            update defaults;
        }
    }

    @TestVisible
    private String buildScheduleKey(Id userId, String scheduleExternalId) {
        return String.valueOf(userId) + ':' + scheduleExternalId;
    }

    @TestVisible
    private String normalizeDayName(String dayName) {
        if (String.isBlank(dayName)) {
            return null;
        }
        String lower = dayName.toLowerCase();
        if (lower.startsWith('mon')) return 'Monday';
        if (lower.startsWith('tue')) return 'Tuesday';
        if (lower.startsWith('wed')) return 'Wednesday';
        if (lower.startsWith('thu')) return 'Thursday';
        if (lower.startsWith('fri')) return 'Friday';
        if (lower.startsWith('sat')) return 'Saturday';
        if (lower.startsWith('sun')) return 'Sunday';
        return dayName.substring(0, 1).toUpperCase() + dayName.substring(1).toLowerCase();
    }

    private String formatTimeKey(Time t) {
        return String.valueOf(t.hour()).leftPad(2, '0') + String.valueOf(t.minute()).leftPad(2, '0');
    }

    @TestVisible
    private class ScheduleRow {
        public String workerId;
        public String email;
        public String scheduleExternalId;
        public String windowExternalId;
        public String dayName;
        public Time startTime;
        public Time endTime;
        public String timeZone;
        public String location;
    }

    private class WorkerSchedule {
        public Id userId;
        public String externalId;
        public String timeZone;
        public String location;
        public List<ScheduleRow> windows = new List<ScheduleRow>();
    }
}
