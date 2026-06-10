Id bookingId = 'a0571000008Sp6DAAS';
Booking__c b = [
    SELECT Id, Status__c, Booker_Email__c, Booker_Name__c, Host__r.Email, Host__r.Name,
           Title__c, UID__c, Start_DateTime__c, End_DateTime__c, Location__c,
           Event_Type__r.Name
    FROM Booking__c
    WHERE Id = :bookingId
];
Integer beforeInvocations = Limits.getEmailInvocations();
BookingNotificationService.sendBookingConfirmation(new List<Id>{ bookingId });
Integer afterInvocations = Limits.getEmailInvocations();
System.debug('RESULT_BOOKING_ID=' + b.Id);
System.debug('RESULT_STATUS=' + b.Status__c);
System.debug('RESULT_BOOKER=' + b.Booker_Email__c);
System.debug('RESULT_HOST=' + b.Host__r.Email);
System.debug('RESULT_EMAIL_INVOCATIONS=' + (afterInvocations - beforeInvocations));
System.debug('RESULT_INTENDED_RECIPIENTS=2');