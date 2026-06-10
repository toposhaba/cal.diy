public without sharing class WorkdayAbsenceSyncProvider extends HrAbsenceSyncProvider {

    private static final List<String> WORKER_ID_KEYS = new List<String>{
        'Worker_ID', 'worker_id', 'Employee_ID', 'employee_id', 'WorkerId'
    };
    private static final List<String> EMAIL_KEYS = new List<String>{
        'Work_Email', 'work_email', 'Email', 'email', 'Primary_Work_Email'
    };
    private static final List<String> EXTERNAL_ID_KEYS = new List<String>{
        'Absence_ID', 'absence_id', 'Time_Off_Entry_ID', 'time_off_entry_id', 'External_Id', 'id'
    };
    private static final List<String> START_DATE_KEYS = new List<String>{
        'Start_Date', 'start_date', 'Time_Off_Start_Date', 'Absence_Start_Date'
    };
    private static final List<String> END_DATE_KEYS = new List<String>{
        'End_Date', 'end_date', 'Time_Off_End_Date', 'Absence_End_Date'
    };
    private static final List<String> ABSENCE_TYPE_KEYS = new List<String>{
        'Absence_Type', 'absence_type', 'Time_Off_Type', 'Leave_Type'
    };
    private static final List<String> STATUS_KEYS = new List<String>{
        'Status', 'status', 'Approval_Status', 'Time_Off_Status'
    };

    public WorkdayAbsenceSyncProvider(Hr_Integration_Provider__mdt providerConfig) {
        super(providerConfig);
    }

    public override HrSyncService.ProviderSyncResult syncAbsences() {
        HrSyncService.ProviderSyncResult result = new HrSyncService.ProviderSyncResult(config.Provider_Key__c);
        String reportPath = resolveAbsenceReportPath();
        if (String.isBlank(reportPath)) {
            result.errors.add('Absence report path is not configured');
            return result;
        }

        String responseBody = HrReportClient.fetchReport(config.Named_Credential__c, reportPath);
        List<Object> rows = HrReportClient.parseReportRows(responseBody);
        Map<String, Id> workerMap = HrUserResolver.buildWorkerIdMap(config.Worker_Id_User_Field__c);
        Map<String, Id> emailMap = HrUserResolver.buildEmailMap();
        Set<String> feedExternalIds = new Set<String>();
        List<Out_of_Office__c> toUpsert = new List<Out_of_Office__c>();

        for (Object rowObj : rows) {
            Map<String, Object> row = (Map<String, Object>) rowObj;
            AbsenceRow absence = parseAbsenceRow(row);
            if (absence == null || !absence.isApproved) {
                continue;
            }
            Id userId = HrUserResolver.resolveUser(absence.workerId, absence.email, workerMap, emailMap);
            if (userId == null) {
                result.skipped++;
                continue;
            }
            feedExternalIds.add(absence.externalId);
            toUpsert.add(buildOutOfOffice(absence, userId));
        }

        if (!toUpsert.isEmpty()) {
            Database.UpsertResult[] upsertResults = Database.upsert(toUpsert, Out_of_Office__c.External_Id__c, false);
            for (Database.UpsertResult ur : upsertResults) {
                if (ur.isSuccess()) {
                    result.upserted++;
                } else {
                    result.errors.add(ur.getErrors()[0].getMessage());
                }
            }
        }

        result.cancelled += cancelStaleRecords(feedExternalIds);
        return result;
    }

    @TestVisible
    private String resolveAbsenceReportPath() {
        if (String.isNotBlank(config.Absence_Report_Path__c)) {
            return config.Absence_Report_Path__c;
        }
        Scheduling_Settings__mdt settings = Scheduling_Settings__mdt.getInstance('Default');
        return settings != null ? settings.Workday_Absence_Report_Path__c : null;
    }

    @TestVisible
    private AbsenceRow parseAbsenceRow(Map<String, Object> row) {
        String externalId = HrReportClient.getStringValue(row, EXTERNAL_ID_KEYS);
        Date startDate = HrReportClient.parseDateValue(HrReportClient.getStringValue(row, START_DATE_KEYS));
        Date endDate = HrReportClient.parseDateValue(HrReportClient.getStringValue(row, END_DATE_KEYS));
        if (endDate == null) {
            endDate = startDate;
        }
        if (String.isBlank(externalId) || startDate == null) {
            return null;
        }
        AbsenceRow absence = new AbsenceRow();
        absence.externalId = config.Provider_Key__c + ':' + externalId;
        absence.workerId = HrReportClient.getStringValue(row, WORKER_ID_KEYS);
        absence.email = HrReportClient.getStringValue(row, EMAIL_KEYS);
        absence.startDate = startDate;
        absence.endDate = endDate;
        absence.absenceType = HrReportClient.getStringValue(row, ABSENCE_TYPE_KEYS);
        String statusValue = HrReportClient.getStringValue(row, STATUS_KEYS);
        absence.isApproved = String.isBlank(statusValue) || statusValue.equalsIgnoreCase('Approved');
        return absence;
    }

    private Out_of_Office__c buildOutOfOffice(AbsenceRow absence, Id userId) {
        Out_of_Office__c ooo = new Out_of_Office__c(
            External_Id__c = absence.externalId,
            User__c = userId,
            Start_Date__c = absence.startDate,
            End_Date__c = absence.endDate,
            Source__c = config.Provider_Key__c,
            Status__c = 'Approved',
            Absence_Type__c = absence.absenceType,
            Reason__c = String.isNotBlank(absence.absenceType) ? absence.absenceType : 'Workday absence'
        );
        return ooo;
    }

    private Integer cancelStaleRecords(Set<String> feedExternalIds) {
        List<Out_of_Office__c> stale = [
            SELECT Id, Status__c
            FROM Out_of_Office__c
            WHERE Source__c = :config.Provider_Key__c
                AND Status__c = 'Approved'
                AND External_Id__c != null
                AND External_Id__c NOT IN :feedExternalIds
        ];
        for (Out_of_Office__c record : stale) {
            record.Status__c = 'Cancelled';
        }
        if (!stale.isEmpty()) {
            update stale;
        }
        return stale.size();
    }

    @TestVisible
    private class AbsenceRow {
        public String externalId;
        public String workerId;
        public String email;
        public Date startDate;
        public Date endDate;
        public String absenceType;
        public Boolean isApproved;
    }
}
