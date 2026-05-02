public without sharing class TwilioWhatsAppService {

    // ─── STATIC CONFIGURATION ────────────────────────────────────────

    /** Twilio Account SID — used in the API URL path */
    private static final String ACCOUNT_SID = 'AC82350270c3642a63bda44fe178685c99';

    /** Twilio WhatsApp-enabled sender number */
    private static final String FROM_NUMBER = '+14155238886';

    /**
     * Default Twilio Content Template SID.
     * Used by Agentforce for booking confirmations.
     * Overridden per-request via WhatsAppRequest.contentSid.
     * HX + 32 hex = 34 chars ✅
     */
    private static final String CONTENT_SID = 'HX994c59f7da9f851450bfed4af04d6ae2';

    /**
     * Named Credential API Name
     * Setup → Named Credentials → New
     *   Label    : Twilio WhatsApp
     *   Name     : Twilio_WhatsApp
     *   URL      : https://api.twilio.com
     *   Auth     : Basic Auth
     *   Username : AC82350270c3642a63bda44fe178685c99  (Account SID)
     *   Password : <your Twilio Auth Token>
     */
    private static final String NAMED_CREDENTIAL = 'Twilio_WhatsApp';

    /** Twilio Messages API path */
    private static final String API_PATH = '/2010-04-01/Accounts/{0}/Messages.json';

    /** Default country code — auto-prepended for bare Indian numbers */
    private static final String DEFAULT_COUNTRY_CODE = '+91';


    // ═════════════════════════════════════════════════════════════════
    //  AGENT ACTION INPUT / OUTPUT WRAPPERS
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Input from Agentforce Agent or TwilioInboundWebhook.
     *              Agentforce passes toNumber + contentVariables only.
     *              TwilioInboundWebhook additionally passes contentSid
     *              to override the default template with the plain
     *              text reply template (no buttons).
     */
    public class WhatsAppRequest {

        @InvocableVariable(
            required    = true
            label       = 'Recipient WhatsApp Number'
            description = 'Customer WhatsApp number. Any Indian format accepted: +919851956424, 9851956424, 09851956424. +91 is auto-prepended if country code is missing.'
        )
        public String toNumber;

        @InvocableVariable(
            required    = true
            label       = 'Content Variables'
            description = 'JSON string for the single template variable. The entire message goes into variable 1. Format: {"1":"<full message>"}'
        )
        public String contentVariables;

        @InvocableVariable(
            required    = false
            label       = 'Content SID Override'
            description = 'Optional. Overrides the default ContentSid. Used by TwilioInboundWebhook to send plain text replies with a different template (no buttons). Leave blank when calling from Agentforce.'
        )
        public String contentSid;
    }

    /**
     * @description Output returned to Agentforce Agent.
     *              Agent uses responseMessage to inform the customer
     *              that the WhatsApp confirmation has been sent.
     */
    public class WhatsAppResponse {

        @InvocableVariable(
            label       = 'Is Successful'
            description = 'True if Twilio accepted the message (HTTP 201). False if validation failed or Twilio returned an error.'
        )
        public Boolean isSuccess;

        @InvocableVariable(
            label       = 'Response Message'
            description = 'Human-readable status to relay back to the customer in the Agentforce conversation.'
        )
        public String responseMessage;

        @InvocableVariable(
            label       = 'Twilio Message SID'
            description = 'The Twilio Message SID (SMxxxx) returned on success. Useful for delivery tracking in Twilio Console → Monitor → Logs → Messaging.'
        )
        public String twilioMessageSid;
    }


    // ═════════════════════════════════════════════════════════════════
    //  PHONE NUMBER NORMALIZATION
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Normalizes any Indian phone number input to E.164 format.
     *
     *   Input variants handled:
     *   +919851956424   → +919851956424  (already E.164, trust it)
     *   +91 7911 123456 → +917911123456  (E.164 with spaces)
     *   9851956424      → +919851956424  (10-digit bare number)
     *   09851956424     → +919851956424  (Indian trunk prefix)
     *   919851956424    → +919851956424  (country code, no plus)
     *   0919851956424   → +919851956424  (091 variant)
     *
     * @param rawNumber  Phone number as typed by customer in chat
     * @return           Normalized E.164 number e.g. +919851956424
     * @throws           IllegalArgumentException if blank or too short
     */
    public static String normalizePhoneNumber(String rawNumber) {

        if (String.isBlank(rawNumber)) {
            throw new IllegalArgumentException('Phone number cannot be blank.');
        }

        Boolean hasPlus = rawNumber.trim().startsWith('+');
        String  cleaned = rawNumber.replaceAll('[^0-9]', '');

        if (cleaned.length() < 10) {
            throw new IllegalArgumentException(
                'Invalid phone number: "' + rawNumber + '". Expected at least 10 digits.'
            );
        }

        // Explicitly provided '+' → trust the country code as-is
        if (hasPlus) {
            return '+' + cleaned;
        }

        // 091XXXXXXXXXX (13+ digits) → +91XXXXXXXXXX
        if (cleaned.startsWith('091') && cleaned.length() >= 13) {
            return '+' + cleaned.substring(1);
        }

        // 91XXXXXXXXXX (12 digits) → +91XXXXXXXXXX
        if (cleaned.startsWith('91') && cleaned.length() >= 12) {
            return '+' + cleaned;
        }

        // 0XXXXXXXXXX (11 digits) → +91XXXXXXXXXX
        if (cleaned.startsWith('0') && cleaned.length() == 11) {
            return DEFAULT_COUNTRY_CODE + cleaned.substring(1);
        }

        // XXXXXXXXXX (10 digits) → +91XXXXXXXXXX
        if (cleaned.length() == 10) {
            return DEFAULT_COUNTRY_CODE + cleaned;
        }

        // Fallback — ambiguous length, prepend + as best guess
        System.debug(LoggingLevel.WARN,
            'TwilioWhatsAppService: Ambiguous number "' + rawNumber +
            '". Prepending + as best guess.');
        return '+' + cleaned;
    }


    // ═════════════════════════════════════════════════════════════════
    //  FUTURE METHOD — POST-DML CALLOUT
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Sends a WhatsApp message asynchronously via @future.
     *              Use this ONLY when a callout is needed after a DML
     *              operation in the same transaction — specifically for
     *              the cancel confirmation in TwilioInboundWebhook after
     *              updating ServiceAppointment.Status = Canceled.
     *
     *              NOT used by Agentforce — Agentforce calls
     *              sendWhatsAppMessages() directly (synchronous).
     *
     * @param toPhone          Normalized E.164 phone number
     * @param contentVariables JSON string e.g. {"1":"<message>"}
     * @param contentSid       Template SID to use
     */
    @future(callout=true)
    public static void sendWhatsAppAfterDml(
        String toPhone,
        String contentVariables,
        String contentSid
    ) {
        WhatsAppRequest req = new WhatsAppRequest();
        req.toNumber         = toPhone;
        req.contentVariables = contentVariables;
        req.contentSid       = contentSid;

        List<WhatsAppResponse> results =
            sendWhatsAppMessages(new List<WhatsAppRequest>{ req });

        if (results != null && !results.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'TwilioWhatsAppService @future | isSuccess: '
                + results[0].isSuccess
                + ' | SID: ' + results[0].twilioMessageSid
                + ' | Message: ' + results[0].responseMessage);
        }
    }


    // ═════════════════════════════════════════════════════════════════
    //  INVOCABLE METHOD — AGENTFORCE ENTRY POINT
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Sends a WhatsApp message via Twilio Content Template API.
     *
     *              Called by:
     *              1. Agentforce Agent Action — booking confirmation
     *                 (contentSid left blank → uses default CONTENT_SID)
     *              2. TwilioInboundWebhook — cancel/reschedule replies
     *                 where no DML precedes the callout (sync)
     *              3. sendWhatsAppAfterDml() @future — cancel confirmation
     *                 after DML (async, fires a few seconds later)
     *
     * @param  requests  List of WhatsAppRequest
     * @return           List of WhatsAppResponse with status + SID
     */
    @InvocableMethod(
        label       = 'Send WhatsApp Booking Confirmation'
        description = 'Sends a WhatsApp template message to the customer via Twilio. Used for booking confirmations (Agentforce) and cancel/reschedule replies (inbound webhook). Pass contentSid to override the default template.'
        category    = 'Messaging'
    )
    public static List<WhatsAppResponse> sendWhatsAppMessages(List<WhatsAppRequest> requests) {
        List<WhatsAppResponse> responses = new List<WhatsAppResponse>();

        for (WhatsAppRequest request : requests) {
            WhatsAppResponse response = new WhatsAppResponse();

            // ── Validate: phone number present ───────────────────────
            if (String.isBlank(request.toNumber)) {
                response.isSuccess       = false;
                response.responseMessage = 'Phone number is missing.';
                responses.add(response);
                continue;
            }

            // ── Normalize phone to E.164 ──────────────────────────────
            String normalizedNumber;
            try {
                normalizedNumber = normalizePhoneNumber(request.toNumber);
            } catch (IllegalArgumentException iae) {
                response.isSuccess       = false;
                response.responseMessage = 'Invalid phone number: ' + iae.getMessage();
                responses.add(response);
                continue;
            }

            // ── Validate: content variables present ──────────────────
            if (String.isBlank(request.contentVariables)) {
                response.isSuccess       = false;
                response.responseMessage = 'Content variables (message) are missing.';
                responses.add(response);
                continue;
            }

            // ── Validate: content variables is valid JSON ────────────
            try {
                JSON.deserializeUntyped(request.contentVariables);
            } catch (System.JSONException je) {
                response.isSuccess       = false;
                response.responseMessage = 'Content variables is not valid JSON. Expected format: {"1":"<message>"}';
                responses.add(response);
                continue;
            }

            // ── Resolve ContentSid ────────────────────────────────────
            // Use override if provided (e.g. from TwilioInboundWebhook)
            // otherwise fall back to default CONTENT_SID (Agentforce)
            String sidToUse = String.isNotBlank(request.contentSid)
                ? request.contentSid
                : CONTENT_SID;

            System.debug('TwilioWhatsAppService | Using ContentSid: ' + sidToUse
                + (String.isNotBlank(request.contentSid) ? ' (override)' : ' (default)'));

            // ── Build and send HTTP request to Twilio ────────────────
            try {
                String endpoint = 'callout:' + NAMED_CREDENTIAL +
                    String.format(API_PATH, new List<String>{ ACCOUNT_SID });

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req.setTimeout(30000);

                String reqBody =
                    'From='              + EncodingUtil.urlEncode('whatsapp:' + FROM_NUMBER, 'UTF-8') +
                    '&To='               + EncodingUtil.urlEncode('whatsapp:' + normalizedNumber, 'UTF-8') +
                    '&ContentSid='       + EncodingUtil.urlEncode(sidToUse, 'UTF-8') +
                    '&ContentVariables=' + EncodingUtil.urlEncode(request.contentVariables.trim(), 'UTF-8');

                req.setBody(reqBody);

                HttpResponse res    = new Http().send(req);
                Integer      status = res.getStatusCode();

                if (status == 201) {
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    response.isSuccess        = true;
                    response.twilioMessageSid = (String) parsed.get('sid');
                    response.responseMessage  =
                        'WhatsApp message sent to ' + normalizedNumber +
                        '. Message SID: ' + response.twilioMessageSid;

                    System.debug(LoggingLevel.INFO,
                        'TwilioWhatsAppService ✅ Sent to: ' + normalizedNumber +
                        ' | SID: ' + response.twilioMessageSid +
                        ' | ContentSid: ' + sidToUse);

                } else {
                    response.isSuccess       = false;
                    response.responseMessage =
                        'Twilio returned an error (HTTP ' + status + '). Please try again.';
                    logFailure(normalizedNumber, request.contentVariables,
                        sidToUse, status, res.getBody());
                }

            } catch (System.CalloutException ce) {
                response.isSuccess       = false;
                response.responseMessage = 'Could not reach Twilio. Please try again shortly.';
                logFailure(normalizedNumber, request.contentVariables,
                    sidToUse, null, ce.getMessage());

            } catch (Exception e) {
                response.isSuccess       = false;
                response.responseMessage = 'An unexpected error occurred: ' + e.getMessage();
                logFailure(normalizedNumber, request.contentVariables,
                    sidToUse, null, e.getMessage() + '\n' + e.getStackTraceString());
            }

            responses.add(response);
        }

        return responses;
    }


    // ═════════════════════════════════════════════════════════════════
    //  ERROR LOGGING
    // ═════════════════════════════════════════════════════════════════

    /**
     * @description Logs Twilio failures with full context for debugging.
     *              Extend this to insert into a Message_Log__c custom
     *              object or publish a Platform Event for monitoring.
     */
    private static void logFailure(String toNumber, String contentVariables,
                                    String contentSid, Integer statusCode,
                                    String errorDetail) {
        System.debug(LoggingLevel.ERROR,
            '\n=== TWILIO WHATSAPP FAILURE ===' +
            '\n  To:               ' + toNumber +
            '\n  From:             ' + FROM_NUMBER +
            '\n  ContentSid:       ' + contentSid +
            '\n  ContentVariables: ' + contentVariables +
            '\n  HTTP Status:      ' + statusCode +
            '\n  Error:            ' + errorDetail +
            '\n==============================='
        );
    }
}
