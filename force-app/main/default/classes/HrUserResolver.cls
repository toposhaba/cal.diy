public without sharing class HrUserResolver {

    public static Map<String, Id> buildWorkerIdMap(String workerIdFieldApi) {
        Map<String, Id> result = new Map<String, Id>();
        if (String.isBlank(workerIdFieldApi)) {
            return result;
        }
        Map<String, Schema.SObjectField> userFields = Schema.SObjectType.User.fields.getMap();
        if (!userFields.containsKey(workerIdFieldApi)) {
            return result;
        }
        String query = 'SELECT Id, ' + workerIdFieldApi + ' FROM User WHERE IsActive = true AND ' +
            workerIdFieldApi + ' != null';
        for (User u : Database.query(query)) {
            String workerId = String.valueOf(u.get(workerIdFieldApi));
            if (String.isNotBlank(workerId)) {
                result.put(workerId, u.Id);
            }
        }
        return result;
    }

    public static Map<String, Id> buildEmailMap() {
        Map<String, Id> result = new Map<String, Id>();
        for (User u : [SELECT Id, Email FROM User WHERE IsActive = true AND Email != null]) {
            result.put(u.Email.toLowerCase(), u.Id);
        }
        return result;
    }

    public static Id resolveUser(
        String workerId,
        String email,
        Map<String, Id> workerMap,
        Map<String, Id> emailMap
    ) {
        if (String.isNotBlank(workerId) && workerMap.containsKey(workerId)) {
            return workerMap.get(workerId);
        }
        if (String.isNotBlank(email)) {
            String normalized = email.toLowerCase();
            if (emailMap.containsKey(normalized)) {
                return emailMap.get(normalized);
            }
        }
        return null;
    }
}
