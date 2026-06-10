public without sharing class BookingNotificationService {

    private static final String SENDER_DISPLAY_NAME = 'Cal.DIY Scheduling';

    private static Id cachedOrgWideEmailAddressId;
    private static Boolean orgWideEmailAddressResolved = false;

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
        for (Integer i = 0; i < results.size(); i++) {
            Messaging.SendEmailResult result = results[i];
            if (result.isSuccess()) {
                continue;
            }

            List<String> targets = emails[i].getToAddresses();
            String targetLabel = targets != null && !targets.isEmpty() ? String.join(targets, ', ') : 'unknown';
            for (Messaging.SendEmailError error : result.getErrors()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Booking email failed for ' + targetLabel + ': ' +
                    error.getStatusCode() + ' - ' + error.getMessage()
                );
            }
        }
    }

        private static void configureOutboundEmail(Messaging.SingleEmailMessage email) {
        email.setSaveAsActivity(false);
        Id orgWideEmailAddressId = resolveOrgWideEmailAddressId();
        if (orgWideEmailAddressId != null) {
            email.setOrgWideEmailAddressId(orgWideEmailAddressId);
        } else {
            email.setSenderDisplayName(SENDER_DISPLAY_NAME);
        }
    }

    private static Id resolveOrgWideEmailAddressId() {
        if (orgWideEmailAddressResolved) {
            return cachedOrgWideEmailAddressId;
        }

        orgWideEmailAddressResolved = true;
        List<OrgWideEmailAddress> orgWideEmails = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE IsVerified = true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        cachedOrgWideEmailAddressId = orgWideEmails.isEmpty() ? null : orgWideEmails[0].Id;
        return cachedOrgWideEmailAddressId;
    }

    @TestVisible
    private static void resetOrgWideEmailCacheForTest() {
        cachedOrgWideEmailAddressId = null;
        orgWideEmailAddressResolved = false;
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
        email.setHtmlBody(buildBookerConfirmationHtml(booking));
        configureOutboundEmail(email);
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
        email.setHtmlBody(buildHostNotificationHtml(booking));
        configureOutboundEmail(email);
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
        configureOutboundEmail(email);
        return email;
    }

    private static Messaging.SingleEmailMessage buildRescheduleEmail(Booking__c booking, String toEmail, String recipientName) {
        if (String.isBlank(toEmail)) {
            return null;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });
        email.setSubject('Booking Rescheduled: ' + booking.Event_Type__r.Name);
        email.setHtmlBody(buildRescheduleHtml(booking));
        configureOutboundEmail(email);
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
        configureOutboundEmail(email);
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
        configureOutboundEmail(email);
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
        configureOutboundEmail(email);
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

    @TestVisible
    private static String buildBookerConfirmationHtml(Booking__c booking) {
        return '<h2>Your booking is confirmed!</h2>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>Host:</strong> ' + String.valueOf(booking.Host__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '') +
            '<p><strong>Reference:</strong> ' + booking.UID__c + '</p>' +
            buildCalendarActionButtonsHtml(booking) +
            '<hr/>' +
            '<p style="color: #666; font-size: 12px;">Need to make changes? Use your booking reference to reschedule or cancel.</p>';
    }

    @TestVisible
    private static String buildHostNotificationHtml(Booking__c booking) {
        return '<h2>You have a new booking!</h2>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>With:</strong> ' + String.valueOf(booking.Booker_Name__c).escapeHtml4() +
            ' (' + String.valueOf(booking.Booker_Email__c).escapeHtml4() + ')</p>' +
            '<p><strong>When:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '') +
            buildCalendarActionButtonsHtml(booking);
    }

    @TestVisible
    private static String buildRescheduleHtml(Booking__c booking) {
        return '<h2>Booking Rescheduled</h2>' +
            '<p>Your booking has been moved to a new time:</p>' +
            '<p><strong>Meeting:</strong> ' + String.valueOf(booking.Event_Type__r.Name).escapeHtml4() + '</p>' +
            '<p><strong>New Time:</strong> ' + booking.Start_DateTime__c.format('EEEE, MMMM d, yyyy h:mm a') +
            ' - ' + booking.End_DateTime__c.format('h:mm a') + '</p>' +
            (String.isNotBlank(booking.Location__c) ? '<p><strong>Where:</strong> ' + booking.Location__c.escapeHtml4() + '</p>' : '') +
            buildCalendarActionButtonsHtml(booking);
    }

    @TestVisible
    private static String buildCalendarActionButtonsHtml(Booking__c booking) {
        String googleUrl = buildGoogleCalendarUrl(booking);
        String outlookUrl = buildOutlookCalendarUrl(booking);
        return '<p style="margin-top: 20px;">' +
            '<a href="' + googleUrl.escapeHtml4() + '" style="display:inline-block;padding:10px 16px;margin-right:8px;background:#4285f4;color:#ffffff;text-decoration:none;border-radius:4px;font-family:Arial,sans-serif;font-size:14px;">Add to Google Calendar</a>' +
            '<a href="' + outlookUrl.escapeHtml4() + '" style="display:inline-block;padding:10px 16px;background:#0078d4;color:#ffffff;text-decoration:none;border-radius:4px;font-family:Arial,sans-serif;font-size:14px;">Add to Outlook</a>' +
            '</p>' +
            '<p style="color: #666; font-size: 12px;">An invite.ics attachment is also included with this email.</p>';
    }

    @TestVisible
    private static String buildGoogleCalendarUrl(Booking__c booking) {
        String title = getCalendarEventTitle(booking);
        String details = buildCalendarEventDetails(booking);
        String location = booking.Location__c != null ? booking.Location__c : '';
        String dates = formatGoogleCalendarDateTime(booking.Start_DateTime__c) +
            '/' + formatGoogleCalendarDateTime(booking.End_DateTime__c);
        return 'https://calendar.google.com/calendar/render?action=TEMPLATE' +
            '&text=' + urlEncodeParam(title) +
            '&dates=' + urlEncodeParam(dates) +
            '&details=' + urlEncodeParam(details) +
            '&location=' + urlEncodeParam(location);
    }

    @TestVisible
    private static String buildOutlookCalendarUrl(Booking__c booking) {
        String title = getCalendarEventTitle(booking);
        String details = buildCalendarEventDetails(booking);
        String location = booking.Location__c != null ? booking.Location__c : '';
        return 'https://outlook.office.com/calendar/0/deeplink/compose?path=/calendar/action/compose&rru=addevent' +
            '&subject=' + urlEncodeParam(title) +
            '&startdt=' + urlEncodeParam(formatOutlookDateTime(booking.Start_DateTime__c)) +
            '&enddt=' + urlEncodeParam(formatOutlookDateTime(booking.End_DateTime__c)) +
            '&body=' + urlEncodeParam(details) +
            '&location=' + urlEncodeParam(location);
    }

    private static String getCalendarEventTitle(Booking__c booking) {
        if (String.isNotBlank(booking.Title__c)) {
            return booking.Title__c;
        }
        if (booking.Event_Type__r != null && String.isNotBlank(booking.Event_Type__r.Name)) {
            return booking.Event_Type__r.Name;
        }
        return 'Cal.DIY Booking';
    }

    private static String buildCalendarEventDetails(Booking__c booking) {
        List<String> lines = new List<String>();
        if (booking.Host__r != null && String.isNotBlank(booking.Host__r.Name)) {
            lines.add('Host: ' + booking.Host__r.Name);
        }
        if (String.isNotBlank(booking.Booker_Name__c)) {
            String bookerLine = 'Booker: ' + booking.Booker_Name__c;
            if (String.isNotBlank(booking.Booker_Email__c)) {
                bookerLine += ' (' + booking.Booker_Email__c + ')';
            }
            lines.add(bookerLine);
        }
        if (String.isNotBlank(booking.UID__c)) {
            lines.add('Reference: ' + booking.UID__c);
        }
        return String.join(lines, '\n');
    }

    private static String formatGoogleCalendarDateTime(Datetime dt) {
        return dt.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
    }

    private static String formatOutlookDateTime(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static String urlEncodeParam(String value) {
        return EncodingUtil.urlEncode(value != null ? value : '', 'UTF-8');
    }
}
