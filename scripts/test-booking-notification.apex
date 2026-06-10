List<Booking__c> bookings = [
    SELECT Id, Booker_Email__c, UID__c
    FROM Booking__c
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.debug('Testing booking: ' + bookings[0].UID__c + ' -> ' + bookings[0].Booker_Email__c);
BookingNotificationService.sendBookingConfirmation(new List<Id>{ bookings[0].Id });
System.debug('sendBookingConfirmation invoked');
