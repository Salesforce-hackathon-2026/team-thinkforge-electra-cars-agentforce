@RestResource(urlMapping='/twilio/inbound')
global without sharing class TwilioInboundWebhook {

    // ─── CONTENT SID ─────────────────────────────────────────────────
    // Plain text template ({{1}} body, no buttons)
    private static final String INBOUND_CONTENT_SID =
        'HX69201e2a0bc822dbd3ae4a9948c993c3';

    // ─── DML FLAG ────────────────────────────────────────────────────
    // Set to true after any DML so subsequent sendWhatsApp() calls
    // use @future to avoid callout-after-DML error
    private static Boolean dmlPerformed = false;

    // ─── TRIGGER KEYWORDS (case-insensitive) ─────────────────────────

    private static final Set<String> CANCEL_TRIGGERS = new Set<String>{
        'cancel', 'cancellation', 'cancel booking',
        'i want to cancel', 'please cancel',
        'cancel my booking', 'cancel test drive'
    };

    private static final Set<String> RESCHEDULE_TRIGGERS = new Set<String>{
        'reschedule', 'change date', 'change time',
        'change booking', 'i want to reschedule',
        'please reschedule', 'reschedule booking',
        'reschedule test drive', 'change my booking'
    };

    private static final Set<String> YES_KEYWORDS = new Set<String>{
        'yes', 'yeah', 'yep', 'sure', 'ok', 'okay',
        'y', 'yes please', 'rebook', 'book again'
    };

    private static final Set<String> NO_KEYWORDS = new Set<String>{
        'no', 'nope', 'nah', 'n', 'no thanks',
        'no thank you', 'not now', 'maybe later'
    };

    private static final String WEBSITE_URL =
        'https://orgfarm-543580c7c8.my.site.com/ElectraCarsWeb/s/';


    // ═════════════════════════════════════════════════════════════════
    //  MAIN ENTRY POINT
    // ═════════════════════════════════════════════════════════════════

    @HttpPost
    global static void handleInbound() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String fromRaw = req.params.get('From');
            String bodyRaw = req.params.get('Body');

            if (String.isBlank(fromRaw) || String.isBlank(bodyRaw)) {
                sendTwimlResponse(res);
                return;
            }

            String fromPhone  = fromRaw.replace('whatsapp:', '').trim();
            String normalized = TwilioWhatsAppService.normalizePhoneNumber(fromPhone);
            String msgBody    = bodyRaw.trim();
            String msgLower   = msgBody.toLowerCase();
            String msgUpper   = msgBody.toUpperCase();

            System.debug('TwilioInbound | From: ' + normalized
                + ' | Body: ' + msgBody);

            if (msgUpper.startsWith('CANCEL ')) {
                String saId = msgBody.trim().substring(7).trim();
                handleCancelConfirmation(normalized, saId);

            } else if (msgUpper.startsWith('RESCHEDULE ')) {
                String saId = msgBody.trim().substring(11).trim();
                handleRescheduleConfirmation(normalized, saId);

            } else if (CANCEL_TRIGGERS.contains(msgLower)) {
                sendCancelPrompt(normalized);

            } else if (RESCHEDULE_TRIGGERS.contains(msgLower)) {
                sendReschedulePrompt(normalized);

            } else if (YES_KEYWORDS.contains(msgLower)) {
                handleRebookYes(normalized);

            } else if (NO_KEYWORDS.contains(msgLower)) {
                handleRebookNo(normalized);

            } else {
                sendHelpMenu(normalized);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'TwilioInbound EXCEPTION: ' + e.getMessage()
                + '\n' + e.getStackTraceString());
        }

        sendTwimlResponse(res);
    }


    // ═════════════════════════════════════════════════════════════════
    //  MESSAGE HANDLERS
    // ═════════════════════════════════════════════════════════════════

    private static void sendCancelPrompt(String phone) {
        sendWhatsApp(phone,
            'To confirm the cancellation of your test drive, '
            + 'please reply with:\n\n'
            + '*CANCEL <your Booking ID>*\n\n'
            + 'Example: CANCEL 08pak000000XXXXX\n\n'
            + '_Your Booking ID is in your original '
            + 'booking confirmation message._');
    }

    private static void sendReschedulePrompt(String phone) {
        sendWhatsApp(phone,
            'To reschedule your test drive, please reply with:\n\n'
            + '*RESCHEDULE <your Booking ID>*\n\n'
            + 'Example: RESCHEDULE 08pak000000XXXXX\n\n'
            + '_Your Booking ID is in your original '
            + 'booking confirmation message._');
    }

    /**
     * @description Handles "CANCEL <SA Id>" — verifies phone, cancels SA,
     *              sends confirmation. Uses @future for the confirmation
     *              message since it follows a DML operation.
     */
    private static void handleCancelConfirmation(String phone, String saId) {

        if (!isValidSalesforceId(saId)) {
            sendWhatsApp(phone,
                'That doesn\'t look like a valid Booking ID. 🤔\n\n'
                + 'Please check your confirmation message and try again:\n\n'
                + '*CANCEL <your Booking ID>*\n\n'
                + 'If you need help, reply *HELP*.');
            return;
        }

        List<ServiceAppointment> sas = [
            SELECT Id, Status, Phone,
                   AppointmentNumber,
                   SchedStartTime,
                   ServiceTerritory.Name
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];

        if (sas.isEmpty()) {
            sendWhatsApp(phone,
                'We couldn\'t find a booking with ID *' + saId + '*. 🤔\n\n'
                + 'Please check your Booking ID and try again:\n\n'
                + '*CANCEL <your Booking ID>*\n\n'
                + 'If you need help, reply *HELP*.');
            return;
        }

        ServiceAppointment sa = sas[0];

        // ── SECURITY: verify phone before DML ────────────────────────
        if (!verifyPhoneMatch(phone, sa.Phone)) {
            System.debug(LoggingLevel.WARN,
                'TwilioInbound SECURITY: Phone mismatch for SA '
                + saId + ' | Inbound: ' + phone
                + ' | SA Phone: ' + sa.Phone);
            sendWhatsApp(phone,
                'We couldn\'t verify this booking against your '
                + 'phone number. 🔒\n\n'
                + 'Please contact us directly for assistance:\n'
                + WEBSITE_URL);
            return;
        }

        String dealer   = sa.ServiceTerritory != null
                          ? sa.ServiceTerritory.Name : 'your dealership';
        String schedStr = sa.SchedStartTime != null
                          ? sa.SchedStartTime.format('EEE, MMM d \'at\' h:mm a')
                          : 'your scheduled time';

        if (sa.Status == 'Canceled') {
            sendWhatsApp(phone,
                'This booking is already *cancelled*. ℹ️\n\n'
                + '📋 Booking ID: ' + saId + '\n\n'
                + 'Would you like to book a new test drive?\n'
                + 'Reply *Yes* to rebook or visit:\n' + WEBSITE_URL);
            return;
        }

        if (sa.Status == 'Completed') {
            sendWhatsApp(phone,
                'This test drive is already *completed* ✅ and '
                + 'cannot be cancelled.\n\n'
                + 'Would you like to book another test drive?\n'
                + 'Reply *Yes* or visit:\n' + WEBSITE_URL);
            return;
        }

        // ── DML: Cancel the SA ────────────────────────────────────────
        // Record-triggered Flow fires automatically to update
        // TestDrive__c and related records.
        update new ServiceAppointment(
            Id     = sa.Id,
            Status = 'Canceled'
        );

        // ── Flag DML performed — next sendWhatsApp uses @future ───────
        dmlPerformed = true;

        System.debug('TwilioInbound ✅ Cancelled SA: ' + saId
            + ' | Phone verified: ' + phone);

        // ── Send confirmation — uses @future (post-DML) ───────────────
        sendWhatsApp(phone,
            '✅ *Your test drive has been cancelled.*\n\n'
            + '📋 Booking ID: ' + saId + '\n'
            + '📍 Dealership: ' + dealer + '\n'
            + '📅 Was scheduled: ' + schedStr + '\n\n'
            + 'Would you like to *rebook* a new test drive? 🚗\n\n'
            + 'Reply *Yes* to rebook or *No* if you\'re all set.');
    }

    /**
     * @description Handles "RESCHEDULE <SA Id>" — verifies phone,
     *              shows current booking, directs to website.
     *              No DML so stays synchronous.
     */
    private static void handleRescheduleConfirmation(String phone, String saId) {

        if (!isValidSalesforceId(saId)) {
            sendWhatsApp(phone,
                'That doesn\'t look like a valid Booking ID. 🤔\n\n'
                + 'Please check your confirmation message and try again:\n\n'
                + '*RESCHEDULE <your Booking ID>*\n\n'
                + 'If you need help, reply *HELP*.');
            return;
        }

        List<ServiceAppointment> sas = [
            SELECT Id, Status, Phone,
                   AppointmentNumber,
                   SchedStartTime,
                   ServiceTerritory.Name
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];

        if (sas.isEmpty()) {
            sendWhatsApp(phone,
                'We couldn\'t find a booking with ID *' + saId + '*. 🤔\n\n'
                + 'Please check your Booking ID and try again:\n\n'
                + '*RESCHEDULE <your Booking ID>*\n\n'
                + 'If you need help, reply *HELP*.');
            return;
        }

        ServiceAppointment sa = sas[0];

        if (!verifyPhoneMatch(phone, sa.Phone)) {
            System.debug(LoggingLevel.WARN,
                'TwilioInbound SECURITY: Phone mismatch for SA '
                + saId + ' | Inbound: ' + phone
                + ' | SA Phone: ' + sa.Phone);
            sendWhatsApp(phone,
                'We couldn\'t verify this booking against your '
                + 'phone number. 🔒\n\n'
                + 'Please contact us directly for assistance:\n'
                + WEBSITE_URL);
            return;
        }

        String dealer   = sa.ServiceTerritory != null
                          ? sa.ServiceTerritory.Name : 'your dealership';
        String schedStr = sa.SchedStartTime != null
                          ? sa.SchedStartTime.format('EEE, MMM d \'at\' h:mm a')
                          : 'your scheduled time';

        if (sa.Status == 'Canceled' || sa.Status == 'Completed') {
            sendWhatsApp(phone,
                'This booking is *' + sa.Status + '* and cannot '
                + 'be rescheduled. ℹ️\n\n'
                + 'Would you like to book a new test drive?\n'
                + 'Reply *Yes* or visit:\n' + WEBSITE_URL);
            return;
        }

        sendWhatsApp(phone,
            '📅 *Let\'s get your test drive rescheduled!*\n\n'
            + '📋 Booking ID: ' + saId + '\n'
            + '📍 Dealership: ' + dealer + '\n'
            + '📅 Current slot: ' + schedStr + '\n\n'
            + 'To pick a new slot, please visit our website — '
            + 'our AI assistant will help you choose a new date and time:\n\n'
            + WEBSITE_URL);
    }

    private static void handleRebookYes(String phone) {
        sendWhatsApp(phone,
            '🎉 *Let\'s book your new test drive!*\n\n'
            + 'Please visit our website — our AI assistant '
            + 'will help you pick a new slot:\n\n'
            + WEBSITE_URL + '\n\n'
            + 'See you soon at Electra Cars! 🚗✨');
    }

    private static void handleRebookNo(String phone) {
        sendWhatsApp(phone,
            'No problem! 👋\n\n'
            + 'We hope to see you at Electra Cars soon. '
            + 'If you ever want to book a test drive, '
            + 'just message us here or visit our website.\n\n'
            + 'Have a great day! 🚗✨');
    }

    private static void sendHelpMenu(String phone) {
        sendWhatsApp(phone,
            'Hi! 👋 I can help you with your Electra Cars test drive.\n\n'
            + '🔴 To *cancel*, reply:\n'
            + 'CANCEL <Booking ID>\n\n'
            + '📅 To *reschedule*, reply:\n'
            + 'RESCHEDULE <Booking ID>\n\n'
            + '_Your Booking ID is in your original '
            + 'booking confirmation message._');
    }


    // ═════════════════════════════════════════════════════════════════
    //  SECURITY HELPER
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Verifies inbound phone matches SA.Phone (E.164 normalized).
     *              Returns true if SA has no phone (backwards compat).
     */
    private static Boolean verifyPhoneMatch(
        String inboundPhone,
        String saPhone
    ) {
        if (String.isBlank(saPhone)) {
            System.debug(LoggingLevel.WARN,
                'TwilioInbound: SA has no Phone — skipping verification');
            return true;
        }

        try {
            String normalizedSaPhone =
                TwilioWhatsAppService.normalizePhoneNumber(saPhone);
            System.debug('TwilioInbound | Verifying: '
                + inboundPhone + ' == ' + normalizedSaPhone);
            return inboundPhone == normalizedSaPhone;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'TwilioInbound: Could not normalize SA phone "'
                + saPhone + '" — ' + e.getMessage());
            return true;
        }
    }


    // ═════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Validates SA Id format.
     *              All SA Ids start with '08' regardless of org.
     *              Accepts both 15-char and 18-char Ids.
     */
    private static Boolean isValidSalesforceId(String idStr) {
        if (String.isBlank(idStr)) return false;
        if (idStr.length() != 15 && idStr.length() != 18) return false;
        if (!idStr.toLowerCase().startsWith('08')) return false;
        return true;
    }

    /**
     * @description Sends WhatsApp message via TwilioWhatsAppService.
     *              If dmlPerformed = true, uses @future method to avoid
     *              callout-after-DML error. Otherwise sends synchronously.
     *              Escapes special characters for valid JSON.
     */
    private static void sendWhatsApp(String toPhone, String message) {
        String escaped = message
            .replace('\\', '\\\\')
            .replace('"', '\\"')
            .replace('\n', '\\n')
            .replace('\r', '\\r');

        String cv  = '{"1":"' + escaped + '"}';
        String sid = INBOUND_CONTENT_SID;

        if (dmlPerformed) {
            // Post-DML: use @future to avoid callout-after-DML error
            System.debug('TwilioInbound | Using @future for post-DML callout');
            TwilioWhatsAppService.sendWhatsAppAfterDml(toPhone, cv, sid);
        } else {
            // No DML yet: send synchronously
            TwilioWhatsAppService.WhatsAppRequest req =
                new TwilioWhatsAppService.WhatsAppRequest();
            req.toNumber         = toPhone;
            req.contentVariables = cv;
            req.contentSid       = sid;
            TwilioWhatsAppService.sendWhatsAppMessages(
                new List<TwilioWhatsAppService.WhatsAppRequest>{ req }
            );
        }
    }

    /**
     * @description Return empty TwiML 200 OK to Twilio.
     */
    private static void sendTwimlResponse(RestResponse res) {
        res.statusCode   = 200;
        res.responseBody = Blob.valueOf(
            '<?xml version="1.0" encoding="UTF-8"?><Response></Response>'
        );
        res.addHeader('Content-Type', 'text/xml');
    }
}
