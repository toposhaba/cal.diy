public without sharing class BookingNotificationService {

    public static void sendBookingConfirmation(List<Id> bookingIds) {
        List<Booking__c> bookings = queryBookings(bookingIds, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Location__c', 'Status__c', 'Booker_Email__c', 'Booker_Name__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name', 'Event_Type__r.Duration_Minutes__c'
        });

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c booking : bookings) {
            addEmailIfValid(emails, buildBookerConfirmationEmail(booking, booking.Booker_Email__c, booking.Booker_Name__c));
            addEmailIfValid(emails, buildHostNotificationEmail(booking));
        }
        dispatchEmails(emails);
    }

    public static void sendSeatConfirmation(Id bookingId, String attendeeEmail, String attendeeName) {
        if (String.isBlank(attendeeEmail)) {
            return;
        }

        List<Booking__c> bookings = queryBookings(new List<Id>{ bookingId }, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Location__c', 'Status__c', 'Booker_Email__c', 'Booker_Name__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name', 'Event_Type__r.Duration_Minutes__c'
        });

        if (bookings.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        addEmailIfValid(emails, buildBookerConfirmationEmail(bookings[0], attendeeEmail, attendeeName));
        dispatchEmails(emails);
    }

    public static void sendCancellationNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = queryBookings(bookingIds, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Booker_Email__c', 'Booker_Name__c', 'Cancellation_Reason__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name'
        });

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c booking : bookings) {
            addEmailIfValid(emails, buildCancellationEmail(booking, booking.Booker_Email__c, booking.Booker_Name__c));
            addEmailIfValid(emails, buildCancellationEmail(booking, booking.Host__r.Email, booking.Host__r.Name));
        }
        dispatchEmails(emails);
    }

    public static void sendRescheduleNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = queryBookings(bookingIds, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Location__c', 'Booker_Email__c', 'Booker_Name__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name', 'Event_Type__r.Duration_Minutes__c'
        });

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c booking : bookings) {
            addEmailIfValid(emails, buildRescheduleEmail(booking, booking.Booker_Email__c, booking.Booker_Name__c));
            addEmailIfValid(emails, buildRescheduleEmail(booking, booking.Host__r.Email, booking.Host__r.Name));
        }
        dispatchEmails(emails);
    }

    public static void sendPendingApprovalNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name
            FROM Booking__c
            WHERE Id IN :bookingIds AND Status__c = 'Pending'
            WITH SYSTEM_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c booking : bookings) {
            addEmailIfValid(emails, buildPendingApprovalEmail(booking));
            addEmailIfValid(emails, buildPendingBookerEmail(booking));
        }
        dispatchEmails(emails);
    }

    public static void sendPendingPaymentNotice(List<Id> bookingIds) {
        List<Booking__c> bookings = [
            SELECT Id, UID__c, Title__c, Start_DateTime__c, End_DateTime__c,
                   Booker_Email__c, Booker_Name__c,
                   Host__c, Host__r.Name, Host__r.Email,
                   Event_Type__r.Name, Event_Type__r.Price__c
            FROM Booking__c
            WHERE Id IN :bookingIds AND Status__c = 'Pending_Payment'
            WITH SYSTEM_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Booking__c booking : bookings) {
            addEmailIfValid(emails, buildPendingPaymentEmail(booking));
        }
        dispatchEmails(emails);
    }

    @TestVisible
    private static Integer buildSeatConfirmationEmailCount(Id bookingId, String attendeeEmail) {
        if (String.isBlank(attendeeEmail)) {
            return 0;
        }

        List<Booking__c> bookings = queryBookings(new List<Id>{ bookingId }, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Location__c', 'Status__c', 'Booker_Email__c', 'Booker_Name__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name', 'Event_Type__r.Duration_Minutes__c'
        });

        if (bookings.isEmpty()) {
            return 0;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        addEmailIfValid(emails, buildBookerConfirmationEmail(bookings[0], attendeeEmail, 'Seat Booker'));
        return emails.size();
    }

    @TestVisible
    private static Integer buildConfirmationEmailCount(List<Id> bookingIds) {
        List<Booking__c> bookings = queryBookings(bookingIds, new List<String>{
            'Id', 'UID__c', 'Title__c', 'Start_DateTime__c', 'End_DateTime__c',
            'Location__c', 'Status__c', 'Booker_Email__c', 'Booker_Name__c',
            'Host__c', 'Host__r.Name', 'Host__r.Email',
            'Event_Type__r.Name', 'Event_Type__r.Duration_Minutes__c'
        });

        Integer count = 0;
        for (Booking__c booking : bookings) {
            if (String.isNotBlank(booking.Booker_Email__c)) {
                count++;
            }
            if (booking.Host__r != null && String.isNotBlank(booking.Host__r.Email)) {
                count++;
            }
        }
        return count;
    }

    private static List<Booking__c> queryBookings(List<Id> bookingIds, List<String> fields) {
        if (bookingIds == null || bookingIds.isEmpty()) {
            return new List<Booking__c>();
        }
        String soql = 'SELECT ' + String.join(fields, ', ') +
            ' FROM Booking__c WHERE Id IN :bookingIds WITH SYSTEM_MODE';
        return Database.query(soql);
    }

    private static void addEmailIfValid(List<Messaging.SingleEmailMessage> emails, Messaging.SingleEmailMessage email) {
        if (email == null) {
            return;
        }
        List<String> toAddresses = email.getToAddresses();
        if (toAddresses == null || toAddresses.isEmpty() || String.isBlank(toAddresses[0])) {
            return;
        }
        emails.add(email);
    }

    private static void dispatchEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty() || Test.isRunningTest()) {
            return;
        }

        Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
        for (Messaging.SendEmailResult result : results) {
            if (!result.isSuccess()) {
                for (Messaging.SendEmailError error : result.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Booking email failed: ' + error.getMessage());
                }
            }
        }
    }

    private static Messaging.SingleEmailMessage buildBookerConfirmationEmail(
        Booking__c booking, String toEmail, String recipientName
    ) {
        if (String.isBlank(toEmail)) {
            return null;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });
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
        attachIcsIfAvailable(email, booking.Id);
        return email;
    }

    private static Messaging.SingleEmailMessage buildHostNotificationEmail(Booking__c booking) {
        if (booking.Host__r == null || String.isBlank(booking.Host__r.Email)) {
            return null;
        }

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
        attachIcsIfAvailable(email, booking.Id);
        return email;
    }

    private static Messaging.SingleEmailMessage buildCancellationEmail(Booking__c booking, String toEmail, String recipientName) {
        if (String.isBlank(toEmail)) {
            return null;
        }

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
        if (String.isBlank(toEmail)) {
            return null;
        }

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
        attachIcsIfAvailable(email, booking.Id);
        return email;
    }

    private static Messaging.SingleEmailMessage buildPendingApprovalEmail(Booking__c booking) {
        if (booking.Host__r == null || String.isBlank(booking.Host__r.Email)) {
            return null;
        }

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
        if (String.isBlank(booking.Booker_Email__c)) {
            return null;
        }

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

    private static Messaging.SingleEmailMessage buildPendingPaymentEmail(Booking__c booking) {
        if (String.isBlank(booking.Booker_Email__c)) {
            return null;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ booking.Booker_Email__c });
        email.setSubject('Payment Required: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(
            '<h2>Complete Your Payment</h2>' +
            '<p>Your booking is reserved pending payment.</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            '<p><strong>Amount:</strong> $' + booking.Event_Type__r.Price__c + '</p>' +
            '<p><strong>Reference:</strong> ' + booking.UID__c + '</p>'
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static void attachIcsIfAvailable(Messaging.SingleEmailMessage email, Id bookingId) {
        try {
            Messaging.EmailFileAttachment attachment = IcsGenerator.createIcsAttachment(bookingId);
            if (attachment != null) {
                email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ICS attachment failed for booking ' + bookingId + ': ' + e.getMessage());
        }
    }
}