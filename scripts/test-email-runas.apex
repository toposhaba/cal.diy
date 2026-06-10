User exampleUser = [
    SELECT Id, Email, Username
    FROM User
    WHERE Email LIKE '%@example.com' AND IsActive = true
    LIMIT 1
];
System.debug('Example user: ' + exampleUser.Email);

System.runAs(exampleUser) {
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ 'toposhaba@gmail.com' });
    email.setSubject('Test from example.com user');
    email.setPlainTextBody('runAs test');
    email.setSaveAsActivity(false);
    Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
    System.debug('runAs success: ' + results[0].isSuccess());
    if (!results[0].isSuccess()) {
        System.debug('runAs error: ' + results[0].getErrors()[0].getMessage());
    }
}

List<Booking__c> bookings = [SELECT Id FROM Booking__c ORDER BY CreatedDate DESC LIMIT 1];
if (!bookings.isEmpty()) {
    System.runAs(exampleUser) {
        try {
            BookingNotificationService.sendBookingConfirmation(new List<Id>{ bookings[0].Id });
            System.debug('BookingNotificationService completed under runAs');
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }
}
