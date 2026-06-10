OrgWideEmailAddress[] owe = [SELECT Id, Address, DisplayName, IsVerified FROM OrgWideEmailAddress LIMIT 5];
System.debug('OrgWideEmailAddresses: ' + owe.size());
for (OrgWideEmailAddress o : owe) {
    System.debug(o.Address + ' verified=' + o.IsVerified);
}

List<Booking__c> bookings = [
    SELECT Id, Booker_Email__c, Host__r.Email, Status__c, UID__c
    FROM Booking__c
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.debug('Latest booking count: ' + bookings.size());
if (!bookings.isEmpty()) {
    System.debug('Booking: ' + bookings[0]);
    Booking__c b = [
        SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
               Location__c, Status__c, Booker_Email__c, Booker_Name__c,
               Host__c, Host__r.Name, Host__r.Email,
               Event_Type__r.Name, Event_Type__r.Duration_Minutes__c
        FROM Booking__c
        WHERE Id = :bookings[0].Id
    ];

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ b.Booker_Email__c != null ? b.Booker_Email__c : 'test@example.com' });
    email.setSubject('Test Booking Confirmed: ' + b.Event_Type__r.Name);
    email.setHtmlBody('<h2>Test email</h2><p>Reference: ' + b.UID__c + '</p>');
    email.setSaveAsActivity(false);

    try {
        Messaging.EmailFileAttachment attachment = IcsGenerator.createIcsAttachment(b.Id);
        if (attachment != null) {
            System.debug('ICS attachment created: ' + attachment.getFileName() + ' type=' + attachment.getContentType());
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        }
    } catch (Exception e) {
        System.debug('ICS failed: ' + e.getMessage());
    }

    Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
    for (Messaging.SendEmailResult result : results) {
        System.debug('Success: ' + result.isSuccess());
        if (!result.isSuccess()) {
            for (Messaging.SendEmailError error : result.getErrors()) {
                System.debug('Error: ' + error.getStatusCode() + ' - ' + error.getMessage() + ' fields=' + error.getFields());
            }
        }
    }
}
