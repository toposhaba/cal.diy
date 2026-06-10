public with sharing class RecordBookingsController {

    private static final String CONTEXT_CONTACT = 'Contact';
    private static final String CONTEXT_ACCOUNT = 'Account';
    private static final String CONTEXT_OPPORTUNITY = 'Opportunity';
    private static final String CONTEXT_GENERIC = 'Generic';

    public class BookingInfo {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public Datetime endDateTime { get; set; }
        @AuraEnabled public String formattedStart { get; set; }
        @AuraEnabled public String formattedEnd { get; set; }
        @AuraEnabled public String bookerName { get; set; }
        @AuraEnabled public String bookerEmail { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class RecordBookingsResponse {
        @AuraEnabled public List<BookingInfo> bookings { get; set; }
        @AuraEnabled public String contextType { get; set; }
        @AuraEnabled public String emptyMessage { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static RecordBookingsResponse getBookingsForRecord(Id recordId, String objectApiName) {
        if (recordId == null) {
            throwAuraHandled('Record ID is required');
        }

        String resolvedObjectApiName = resolveObjectApiName(recordId, objectApiName);
        ContactScope scope = resolveContactScope(recordId, resolvedObjectApiName);
        String contextType = resolveContextType(resolvedObjectApiName);

        RecordBookingsResponse response = new RecordBookingsResponse();
        response.contextType = contextType;
        response.bookings = new List<BookingInfo>();

        if (scope.isEmpty() && contextType == CONTEXT_GENERIC) {
            response.emptyMessage = 'No contact lookup fields found on this record.';
            return response;
        }

        List<Booking__c> bookings = queryBookings(scope);
        for (Booking__c booking : bookings) {
            response.bookings.add(toBookingInfo(booking));
        }

        if (response.bookings.isEmpty()) {
            response.emptyMessage = getEmptyMessage(contextType);
        }

        return response;
    }

    private static String resolveObjectApiName(Id recordId, String objectApiName) {
        String typeFromId = recordId.getSObjectType().getDescribe().getName();
        if (String.isBlank(objectApiName)) {
            return typeFromId;
        }
        if (objectApiName != typeFromId) {
            throwAuraHandled('Record ID does not match the object type');
        }
        return typeFromId;
    }

    private static String resolveContextType(String objectApiName) {
        if (objectApiName == CONTEXT_CONTACT) {
            return CONTEXT_CONTACT;
        }
        if (objectApiName == CONTEXT_ACCOUNT) {
            return CONTEXT_ACCOUNT;
        }
        if (objectApiName == CONTEXT_OPPORTUNITY) {
            return CONTEXT_OPPORTUNITY;
        }
        return CONTEXT_GENERIC;
    }

    private static ContactScope resolveContactScope(Id recordId, String objectApiName) {
        ContactScope scope = new ContactScope();

        if (objectApiName == CONTEXT_CONTACT) {
            List<Contact> contacts = [
                SELECT Id, Email
                FROM Contact
                WHERE Id = :recordId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                addContactRecord(scope, contacts[0]);
            }
            return scope;
        }

        if (objectApiName == CONTEXT_ACCOUNT) {
            for (Contact contact : [
                SELECT Id, Email
                FROM Contact
                WHERE AccountId = :recordId
                WITH USER_MODE
            ]) {
                addContactRecord(scope, contact);
            }
            return scope;
        }

        if (objectApiName == CONTEXT_OPPORTUNITY) {
            for (OpportunityContactRole role : [
                SELECT ContactId, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :recordId
                WITH USER_MODE
            ]) {
                if (role.ContactId != null) {
                    scope.contactIds.add(role.ContactId);
                }
                addEmail(scope, role.Contact?.Email);
            }
            return scope;
        }

        return resolveGenericContactScope(recordId, objectApiName);
    }

    private static ContactScope resolveGenericContactScope(Id recordId, String objectApiName) {
        ContactScope scope = new ContactScope();
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) {
            throwAuraHandled('Unsupported object type');
        }

        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        List<String> contactFieldNames = new List<String>();
        for (Schema.SObjectField fieldToken : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            for (Schema.SObjectType referenceType : fieldDescribe.getReferenceTo()) {
                if (referenceType == Contact.SObjectType) {
                    contactFieldNames.add(fieldDescribe.getName());
                    break;
                }
            }
        }

        if (contactFieldNames.isEmpty()) {
            return scope;
        }

        String query = 'SELECT ' + String.join(contactFieldNames, ', ')
            + ' FROM ' + String.escapeSingleQuotes(objectApiName)
            + ' WHERE Id = :recordId WITH USER_MODE LIMIT 1';
        List<SObject> records = Database.query(query);
        if (records.isEmpty()) {
            return scope;
        }

        SObject record = records[0];
        for (String fieldName : contactFieldNames) {
            Id contactId = (Id) record.get(fieldName);
            if (contactId != null) {
                scope.contactIds.add(contactId);
            }
        }

        enrichScopeWithContactEmails(scope);
        return scope;
    }

    private static void enrichScopeWithContactEmails(ContactScope scope) {
        if (scope.contactIds.isEmpty()) {
            return;
        }
        for (Contact contact : [
            SELECT Email
            FROM Contact
            WHERE Id IN :scope.contactIds
            WITH USER_MODE
        ]) {
            addEmail(scope, contact.Email);
        }
    }

    private static void addContactRecord(ContactScope scope, Contact contact) {
        if (contact == null || contact.Id == null) {
            return;
        }
        scope.contactIds.add(contact.Id);
        addEmail(scope, contact.Email);
    }

    private static void addEmail(ContactScope scope, String email) {
        if (String.isBlank(email)) {
            return;
        }
        scope.emails.add(email.trim().toLowerCase());
    }

    private static List<Booking__c> queryBookings(ContactScope scope) {
        if (scope.isEmpty()) {
            return new List<Booking__c>();
        }

        if (!scope.contactIds.isEmpty() && !scope.emails.isEmpty()) {
            return [
                SELECT Id, Title__c, Start_DateTime__c, End_DateTime__c,
                       Status__c, Booker_Name__c, Booker_Email__c, Booker_Contact__c
                FROM Booking__c
                WHERE Booker_Contact__c IN :scope.contactIds
                    OR Booker_Email__c IN :scope.emails
                WITH USER_MODE
                ORDER BY Start_DateTime__c DESC
            ];
        }

        if (!scope.contactIds.isEmpty()) {
            return [
                SELECT Id, Title__c, Start_DateTime__c, End_DateTime__c,
                       Status__c, Booker_Name__c, Booker_Email__c, Booker_Contact__c
                FROM Booking__c
                WHERE Booker_Contact__c IN :scope.contactIds
                WITH USER_MODE
                ORDER BY Start_DateTime__c DESC
            ];
        }

        return [
            SELECT Id, Title__c, Start_DateTime__c, End_DateTime__c,
                   Status__c, Booker_Name__c, Booker_Email__c, Booker_Contact__c
            FROM Booking__c
            WHERE Booker_Email__c IN :scope.emails
            WITH USER_MODE
            ORDER BY Start_DateTime__c DESC
        ];
    }

    private static BookingInfo toBookingInfo(Booking__c booking) {
        BookingInfo info = new BookingInfo();
        info.id = booking.Id;
        info.title = booking.Title__c;
        info.startDateTime = booking.Start_DateTime__c;
        info.endDateTime = booking.End_DateTime__c;
        info.formattedStart = formatDateTime(booking.Start_DateTime__c);
        info.formattedEnd = formatTime(booking.End_DateTime__c);
        info.bookerName = booking.Booker_Name__c;
        info.bookerEmail = booking.Booker_Email__c;
        info.status = booking.Status__c;
        return info;
    }

    private static String formatDateTime(Datetime value) {
        if (value == null) {
            return '';
        }
        return value.format('EEE, MMM d, yyyy h:mm a');
    }

    private static String formatTime(Datetime value) {
        if (value == null) {
            return '';
        }
        return value.format('h:mm a');
    }

    private static String getEmptyMessage(String contextType) {
        if (contextType == CONTEXT_CONTACT) {
            return 'No bookings found for this contact.';
        }
        if (contextType == CONTEXT_ACCOUNT) {
            return 'No bookings found for contacts on this account.';
        }
        if (contextType == CONTEXT_OPPORTUNITY) {
            return 'No bookings found for contacts on this opportunity.';
        }
        return 'No bookings found for linked contacts.';
    }

    private static void throwAuraHandled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        throw ex;
    }

    private class ContactScope {
        Set<Id> contactIds = new Set<Id>();
        Set<String> emails = new Set<String>();

        Boolean isEmpty() {
            return contactIds.isEmpty() && emails.isEmpty();
        }
    }
}
