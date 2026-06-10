public without sharing class HrReportClient {

    @TestVisible
    private static Boolean skipCallouts = false;

    @TestVisible
    private static String mockResponseBody;

    public static String fetchReport(String namedCredential, String reportPath) {
        if (Test.isRunningTest() && skipCallouts && mockResponseBody != null) {
            return mockResponseBody;
        }
        if (String.isBlank(namedCredential) || String.isBlank(reportPath)) {
            throw new SchedulingException('HR_CONFIG_ERROR', 'Named credential and report path are required');
        }
        String path = reportPath.startsWith('/') ? reportPath.substring(1) : reportPath;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCredential + '/' + path);
        req.setMethod('GET');
        req.setTimeout(60000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new SchedulingException(
                'HR_API_ERROR',
                'HR report request failed with status ' + res.getStatusCode()
            );
        }
        return res.getBody();
    }

    @TestVisible
    public static List<Object> parseReportRows(String responseBody) {
        Object parsed = JSON.deserializeUntyped(responseBody);
        if (parsed instanceof List<Object>) {
            return (List<Object>) parsed;
        }
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{ 'Report_Entry', 'report_entry', 'entries', 'data' }) {
            if (root.containsKey(key) && root.get(key) instanceof List<Object>) {
                return (List<Object>) root.get(key);
            }
        }
        return new List<Object>();
    }

    @TestVisible
    public static String getStringValue(Map<String, Object> row, List<String> keys) {
        for (String key : keys) {
            if (row.containsKey(key) && row.get(key) != null) {
                return String.valueOf(row.get(key)).trim();
            }
        }
        return null;
    }

    @TestVisible
    public static Date parseDateValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.length() > 10 ? value.substring(0, 10) : value;
        return Date.valueOf(normalized);
    }

    @TestVisible
    public static Time parseTimeValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        List<String> parts = value.split(':');
        if (parts.size() < 2) {
            return null;
        }
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);
        Integer second = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
        return Time.newInstance(hour, minute, second, 0);
    }
}
