OrgWideEmailAddress[] owe = [SELECT Id, Address, DisplayName, IsVerified FROM OrgWideEmailAddress LIMIT 5];
System.debug('OrgWideEmailAddresses: ' + owe.size());

Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setToAddresses(new List<String>{ 'test@example.com' });
email.setSubject('Test after deliverability');
email.setPlainTextBody('test');
email.setSaveAsActivity(false);
Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
System.debug('Success: ' + results[0].isSuccess());
if (!results[0].isSuccess()) {
    System.debug('Error: ' + results[0].getErrors()[0].getStatusCode() + ' - ' + results[0].getErrors()[0].getMessage());
}
