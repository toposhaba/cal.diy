User u = [SELECT Id, Email, Username FROM User WHERE Id = :UserInfo.getUserId()];
System.debug('Current user email: ' + u.Email);

List<Booking__c> bookings = [SELECT Id, Booker_Email__c FROM Booking__c ORDER BY CreatedDate DESC LIMIT 1];

Messaging.SingleEmailMessage email1 = new Messaging.SingleEmailMessage();
email1.setToAddresses(new List<String>{ u.Email });
email1.setSubject('Test 1 - to self');
email1.setPlainTextBody('plain test');
email1.setSaveAsActivity(false);
Messaging.SendEmailResult[] r1 = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email1 }, false);
System.debug('Test1 to self: success=' + r1[0].isSuccess() + ' err=' + (r1[0].isSuccess() ? '' : r1[0].getErrors()[0].getMessage()));

if (!bookings.isEmpty()) {
    Messaging.SingleEmailMessage email2 = new Messaging.SingleEmailMessage();
    email2.setToAddresses(new List<String>{ bookings[0].Booker_Email__c });
    email2.setSubject('Test 2 - to booker external');
    email2.setPlainTextBody('external test');
    email2.setSaveAsActivity(false);
    Messaging.SendEmailResult[] r2 = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email2 }, false);
    System.debug('Test2 external: success=' + r2[0].isSuccess() + ' err=' + (r2[0].isSuccess() ? '' : r2[0].getErrors()[0].getMessage()));

    Messaging.SingleEmailMessage email3 = new Messaging.SingleEmailMessage();
    email3.setToAddresses(new List<String>{ bookings[0].Booker_Email__c });
    email3.setSubject('Test 3 - external with ICS');
    email3.setPlainTextBody('ics test');
    email3.setSaveAsActivity(false);
    Messaging.EmailFileAttachment att = IcsGenerator.createIcsAttachment(bookings[0].Id);
    email3.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });
    Messaging.SendEmailResult[] r3 = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email3 }, false);
    System.debug('Test3 with ICS: success=' + r3[0].isSuccess() + ' err=' + (r3[0].isSuccess() ? '' : r3[0].getErrors()[0].getMessage()));
}
