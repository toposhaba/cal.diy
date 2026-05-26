public with sharing class BookingNotificationService {

    public static void sendBookingConfirmation(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Location__c, Status__c, Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name, Event_Type__r.Duration_Minutes__c
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Booking__c booking : bookings) {
            emails.add(buildBookerConfirmationEmail(booking));
            emails.add(buildHostNotificationEmail(booking));
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails, false);
        }
    }

    public static void sendCancellationNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Booker_Email__c, Booker_Name__c, Cancellation_Reason__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Booking__c booking : bookings) {
            emails.add(buildCancellationEmail(booking, booking.Booker_Email__c, booking.Booker_Name__c));
            emails.add(buildCancellationEmail(booking, booking.Host__r.Email, booking.Host__r.Name));
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails, false);
        }
    }

    public static void sendRescheduleNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Location__c, Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name, Event_Type__r.Duration_Minutes__c
            FROM Booking__c
            WHERE Id IN :bookingIds
            WITH USER_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Booking__c booking : bookings) {
            emails.add(buildRescheduleEmail(booking, booking.Booker_Email__c, booking.Booker_Name__c));
            emails.add(buildRescheduleEmail(booking, booking.Host__r.Email, booking.Host__r.Name));
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails, false);
        }
    }

    public static void sendPendingApprovalNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name
            FROM Booking__c
            WHERE Id IN :bookingIds AND Status__c = 'Pending'
            WITH USER_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Booking__c booking : bookings) {
            emails.add(buildPendingApprovalEmail(booking));
            emails.add(buildPendingBookerEmail(booking));
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails, false);
        }
    }

    private static Messaging.SingleEmailMessage buildBookerConfirmationEmail(Booking__c booking) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ booking.Booker_Email__c });
        email.setSubject('Booking Confirmed: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Your booking is confirmed!</h2>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>Host:</strong> ' + String.valueOf(booking.Host__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '') +
            '<p><strong>Reference:</strong> ' + booking.UID__c + '</p>' +
            '<hr/>' +
            '<p style="color: #666; font-size: 12px;">Need to make changes? Use your booking reference to reschedule or cancel.</p>'
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildHostNotificationEmail(Booking__c booking) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ booking.Host__r.Email });
        email.setSubject('New Booking: ' + booking.Event_Type__r.Name + ' with ' + booking.Booker_Name__c);
        email.setHtmlBody(
            '<h2>You have a new booking!</h2>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>With:</strong> ' + String.valueOf(booking.Booker_Name__c).escapeHtml4() +
            ' (' + String.valueOf(booking.Booker_Email__c).escapeHtml4() + ')</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '')
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildCancellationEmail(Booking__c booking, String toEmail, String recipientName) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });
        email.setSubject('Booking Cancelled: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Booking Cancelled</h2>' +
            '<p>The following booking has been cancelled:</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>Was scheduled for:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') + '</p>' +
            (String.isNotBlank(booking.Cancellation_Reason__c) ? '<p><strong>Reason:</strong> ' + booking.Cancellation_Reason__c.escapeHtml4() + '</p>' : '')
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildRescheduleEmail(Booking__c booking, String toEmail, String recipientName) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });
        email.setSubject('Booking Rescheduled: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Booking Rescheduled</h2>' +
            '<p>Your booking has been moved to a new time:</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>New Time:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '')
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildPendingApprovalEmail(Booking__c booking) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ booking.Host__r.Email });
        email.setSubject('Booking Requires Approval: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Booking Pending Your Approval</h2>' +
            '<p>A new booking request needs your confirmation:</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>Requested by:</strong> ' + String.valueOf(booking.Booker_Name__c).escapeHtml4() +
            ' (' + String.valueOf(booking.Booker_Email__c).escapeHtml4() + ')</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            '<p>Please log in to confirm or reject this booking.</p>'
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static Messaging.SingleEmailMessage buildPendingBookerEmail(Booking__c booking) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ booking.Booker_Email__c });
        email.setSubject('Booking Request Submitted: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Booking Request Submitted</h2>' +
            '<p>Your booking request has been submitted and is awaiting confirmation from the host.</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>Requested Time:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            '<p><strong>Reference:</strong> ' + booking.UID__c + '</p>' +
            '<p>You will receive a confirmation email once the host approves your request.</p>'
        );
        email.setSaveAsActivity(false);
        return email;
    }
}
