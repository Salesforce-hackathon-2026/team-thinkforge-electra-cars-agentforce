import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getVehicleDetail from '@salesforce/apex/ElectraCmsController.getVehicleDetail';
import getCmsImageUrl from '@salesforce/apex/ElectraCmsController.getCmsImageUrl';
import sendMessageToAgent from '@salesforce/apex/ElectraAgentBridge.sendMessageToAgent';

export default class ElectraConcierge extends NavigationMixin(LightningElement) {
    @track vehicle;
    @track userInput = '';
    @track error;
    @track logoUrl;
    @track city = null;
    @track zipCode = null;
    @track isBookingConfirmed = false;
    @track appointmentDate = null;
    @track appointmentTime = null;
    @track chatMessages = [
        //{ id: 1, text: "Hello! I've pre-configured your request. How can I help?", type: 'agent', bubbleClass: 'msg-container agent' }
    ];
    @track isTyping = false;
    @track isListening = false; // Added for Voice
    @track isSessionActive = true;

    recognition; // Speech API object
    currentSessionId = null;
    embeddedServiceLoaded = false;
    chatInitialized = false;
    contentKey;
    lat;
    lon;

    logoContentKey = 'MCKMNETTZ74NCMFGOWW6N6SLGB4Y';

    // 1. Fetch Brand Logo from CMS
    @wire(getCmsImageUrl, { contentKey: '$logoContentKey' })
    wiredLogo({ data }) {
        if (data) this.logoUrl = data;
    }

    // 2. Capture all URL parameters (ID + Location)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('Page Reference received:', JSON.stringify(currentPageReference));
        if (currentPageReference && currentPageReference.state) {
            this.contentKey = currentPageReference.state.contentKey;
            //this.lat = currentPageReference.state.lat;
            //this.lon = currentPageReference.state.lon;

            // 1. Pick up the "Secret Envelope" from Session Storage
            const hiddenLat = sessionStorage.getItem('electra_lat');
            const hiddenLon = sessionStorage.getItem('electra_lon');
            const hiddenCity = sessionStorage.getItem('electra_city');

            // 2. Assign to local variables so the AgentBridge can use them
            if (hiddenLat) this.lat = hiddenLat;
            if (hiddenLon) this.lon = hiddenLon;
            if (hiddenCity) this.city = hiddenCity;

            console.log('✓ Secret Context Recovered:', { city: this.city, lat: this.lat });

            // 3. Clear storage so it doesn't interfere with the next car/session
            //sessionStorage.removeItem('electra_lat');
            //sessionStorage.removeItem('electra_lon');
            //sessionStorage.removeItem('electra_city');

            if (!this.contentKey) {
                console.warn('No ContentKey found. Loading Mock Data for Preview.');
                this.loadMockData();
            } else if (this.lat && this.lon) {
                this.reverseGeocode();
            }
        }
    }

    // 3. Fetch Car Details from CMS
    @wire(getVehicleDetail, { contentKey: '$contentKey' })
    wiredVehicle({ data, error }) {
        if (data) {
            this.vehicle = data;
            this.error = undefined;
            console.log('✓ Vehicle loaded:', this.vehicle.title);
            console.log('✓ Vehicle Asset ID loaded:', this.vehicle.vehicleAssetId);
        } else if (error) {
            this.error = 'Apex Error: ' + (error.body?.message || 'Unknown');
            console.error('Vehicle Wire Error:', error);
            this.loadMockData();
        }
    }

    loadMockData() {
        this.vehicle = {
            title: 'Electra Convertible (Preview)',
            imageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=1000',
            price: 'Price from ₹ 50, 00, 000/-'
        };
        console.log('✓ Mock vehicle loaded');
    }

    async reverseGeocode() {
        // 1. Guard Clause: Only call the API if we actually have coordinates
        if (!this.lat || !this.lon) {
            console.log('Skipping Reverse Geocode: No coordinates available.');
            return;
        }

        try {
            const response = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${this.lat}&lon=${this.lon}`);
            const data = await response.json();

            // 2. Extract with deeper fallbacks 
            // (Urban areas sometimes use 'suburb' or 'neighbourhood' instead of 'city')
            const detectedCity = data.address.city || 
                             data.address.town || 
                             data.address.village || 
                             data.address.suburb;

            const detectedZip = data.address.postcode;

            // 3. Selective Update: Only overwrite if the API actually returned a result
            if (detectedCity) {
                this.city = detectedCity;
            }
            if (detectedZip) {
                this.zipCode = detectedZip;
            }

            console.log('✓ Location Refined:', { city: this.city, zipCode: this.zipCode });

        } catch (e) {
            // 4. Silent Failure: Keep the existing city/zip from Session Storage
            console.warn('Precision Geocode failed. Preserving fallback context:', this.city);
            // We do NOT set this.city = null here anymore!
        }
    }

    navigateToSpecs() {
        // Determine the spec URL based on whether contentKey exists
        const specUrl = this.contentKey?`/vehicle-detail?contentKey=${this.contentKey}` 
        : 'https://orgfarm-543580c7c8.my.site.com/ElectraCarsWeb/s/';
        
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: specUrl
            }
        });
    }

    /*navigateToVehicle() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/vehicle-detail?contentKey=${this.contentKey}`
            }
        });
    }*/

    navigateToVehicle() {
        // Determine the target URL based on whether contentKey exists
        const targetUrl = this.contentKey?`/vehicle-detail?contentKey=${this.contentKey}` 
        : 'https://orgfarm-543580c7c8.my.site.com/ElectraCarsWeb/s/';

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
                attributes: {
                    url: targetUrl
                }
        });
    }

    // Optional: Add a getter to make the label dynamic too
    get backLinkLabel() {
        return this.contentKey ? '← BACK TO VEHICLE PAGE' : '← BACK TO HOME';
    }

    get heroStyle() { 
        return this.vehicle ? `background-image: linear-gradient(rgba(0,0,0,0.1), rgba(0,0,0,0.5)), url(${this.vehicle.imageUrl});` : ''; 
    }

    get displayPrice() {
        return this.vehicle?.price ? `${this.vehicle.price}` : 'Get quote from dealer';
    }

    // --- VOICE LOGIC ---
    toggleVoice() {
        if (this.isListening) {
            this.recognition.stop();
            return;
        }

        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
            console.error('Browser does not support Speech Recognition.');
            return;
        }

        this.recognition = new SpeechRecognition();
        this.recognition.lang = 'en-US';
        this.recognition.onstart = () => { this.isListening = true; };
        this.recognition.onresult = (event) => {
            const transcript = event.results[0][0].transcript;
            this.userInput = transcript;
            const inputElement = this.template.querySelector('input');
            if (inputElement) inputElement.value = transcript;
        };
        this.recognition.onerror = () => { this.isListening = false; };
        this.recognition.onend = () => { this.isListening = false; };
        this.recognition.start();
    }

    get micBtnClass() {
        return this.isListening ? 'mic-btn-branded listening' : 'mic-btn-branded';
    }

    @api
    simulateBooking() {
        this.isBookingConfirmed = true;
        console.log('Booking Simulation Triggered!');
    }

    connectedCallback() {
        // Load Embedded Service script after component renders
        setTimeout(() => {
           // this.initializeEmbeddedService();
        }, 1000);
    }

    /**
     * Initialize Standard Embedded Service Chat Widget
     * This uses the default Salesforce chat UI
     */
    initializeEmbeddedService() {
        if (this.embeddedServiceLoaded) {
            console.log('Embedded Service already loaded');
            return;
        }

        console.log('=== Loading Standard Embedded Service Chat Widget ===');

        // Create script element for Embedded Service
        const script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://orgfarm-543580c7c8.my.site.com/ESWElectraCarsMessaging1776598872676/assets/js/bootstrap.min.js';
        
        script.onload = () => {
            console.log('✓ Embedded Service script loaded');
            this.embeddedServiceLoaded = true;
            
            // Wait for script to initialize and template to render
            setTimeout(() => {
                this.configureEmbeddedService();
            }, 1000);
        };

        script.onerror = () => {
            console.error('✗ Failed to load Embedded Service script');
            console.error('Please check:');
            console.error('1. Embedded Service deployment is active');
            console.error('2. CSP Trusted Sites are configured');
        };

        document.head.appendChild(script);
    }

    /**
     * Configure embedded service with context passing
     */
    configureEmbeddedService() {
        if (!window.embeddedservice_bootstrap) {
            console.error('✗ embeddedservice_bootstrap not available');
            return;
        }

        if (this.chatInitialized) {
            console.log('Chat already initialized');
            return;
        }

        try {
            console.log('=== Configuring Embedded Chat ===');
            console.log('Version: CONTEXT_V3 - Event-driven context updates');

            // Configure language
            window.embeddedservice_bootstrap.settings.language = 'en_US';
            
            // Log current context
            const context = this.getContextData();
            console.log('✓ Context data available:', context);
            
            // NEW: Set prepopulated prechat fields BEFORE init
            // This is the recommended approach for Agentforce Messaging
            window.embeddedservice_bootstrap.settings.prepopulatedPrechatFields = {
                Vehicle_Asset_ID: this.vehicle?.vehicleAssetId || '',
                Vehicle_Name: this.vehicle?.title || '',
                City: this.city || '',
                Zip_Code: this.zipCode || ''
            };
            
            console.log('✓ Prepopulated prechat fields configured');
            
            // Set up event listeners for chat lifecycle
            this.setupChatEventListeners();
            
            // Initialize the embedded service
            window.embeddedservice_bootstrap.init(
                '00Dak00000ohvxV', // orgId
                'Electra_Cars_Messaging_Channel', // deploymentName  
                'https://orgfarm-543580c7c8.my.site.com/ESWElectraCarsMessaging1776598872676', // deploymentUrl
                {
                    scrt2URL: 'https://orgfarm-543580c7c8.my.salesforce-scrt.com'
                }
            );

            console.log('✓ Embedded Service initialized');
            console.log('✓ Chat button will appear on page');
            console.log('✓ Context will be configured when chat opens');
            this.chatInitialized = true;

        } catch (error) {
            console.error('✗ Error configuring Embedded Service:', error);
        }
    }

    /**
     * Setup event listeners for chat widget lifecycle
     */
    setupChatEventListeners() {
        // Listen for chat button ready event
        window.addEventListener('onEmbeddedMessagingReady', () => {
            console.log('✓ Chat widget ready event fired');
            this.configurePrechatData();
        });

        // Fallback: Poll for embedded_svc availability
        let pollCount = 0;
        const maxPolls = 20; // 10 seconds max
        const pollInterval = setInterval(() => {
            pollCount++;
            
            if (window.embedded_svc) {
                console.log('✓ window.embedded_svc now available');
                clearInterval(pollInterval);
                this.configurePrechatData();
            } else if (pollCount >= maxPolls) {
                console.log('⚠️ window.embedded_svc not available after polling');
                console.log('⚠️ Context will be shown in console for manual entry');
                clearInterval(pollInterval);
                // Still show context in console
                this.logContextForManualEntry();
            }
        }, 500);
    }

    // FIX 2: Better Input Binding
    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    // FIX 3: Robust Enter Key Support
    handleKeyPress(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSendMessage();
        }
    }


    /**
     * Get current context data
     * Changed to pass Vehicle Asset ID instead of Vehicle Name per user requirement
     */
    getContextData() {
        return {
            Vehicle_Asset_ID: this.vehicle?.vehicleAssetId || 'Unknown',
            Vehicle_Name: this.vehicle?.title || 'Unknown Vehicle',
            User_City: this.city || 'Unknown Location',  
            Zip_Code: this.zipCode || 'Not captured'
        };
    }

    /**
     * Configure prechat data to pass context to agent
     * Note: For Agentforce Messaging, prechat configuration is limited
     * Context will be shown in console for manual verification
     */
    configurePrechatData() {
        try {
            const context = this.getContextData();
            
            // Always log context
            this.logContextForManualEntry();
            
            // Attempt to configure if embedded_svc is available
            if (window.embedded_svc) {
                console.log('✓ window.embedded_svc is available');
                
                // Check if settings object exists
                if (!window.embedded_svc.settings) {
                    window.embedded_svc.settings = {};
                }
                
                // Try multiple approaches for maximum compatibility
                
                // Approach 1: prepopulatedPrechatFields (recommended for messaging)
                if (!window.embedded_svc.settings.prepopulatedPrechatFields) {
                    window.embedded_svc.settings.prepopulatedPrechatFields = {
                        Vehicle_Asset_ID: context.Vehicle_Asset_ID,
                        Vehicle_Name: context.Vehicle_Name,
                        City: context.User_City,
                        Zip_Code: context.Zip_Code
                    };
                    console.log('✓ Set prepopulatedPrechatFields on embedded_svc');
                }
                
                // Approach 2: extraPrechatFormDetails (traditional approach)
                const contextData = [
                    {
                        "label": "Vehicle_Asset_ID",
                        "value": context.Vehicle_Asset_ID,
                        "displayToAgent": true
                    },
                    {
                        "label": "Vehicle_Name",
                        "value": context.Vehicle_Name,
                        "displayToAgent": true
                    },
                    {
                        "label": "City",
                        "value": context.User_City,
                        "displayToAgent": true
                    },
                    {
                        "label": "Zip_Code",
                        "value": context.Zip_Code,
                        "displayToAgent": true
                    }
                ];

                window.embedded_svc.settings.extraPrechatFormDetails = contextData;
                window.embedded_svc.settings.extraPrechatInfo = [{
                    "entityFieldMaps": [],
                    "entityName": "Contact"
                }];
                
                console.log('✓ Set extraPrechatFormDetails on embedded_svc');

                console.log('✓ Prechat data configured in embedded_svc.settings');
                console.log('✓ Context should now be passed to agent automatically');
            } else {
                console.log('⚠️ window.embedded_svc not available yet');
                console.log('⚠️ This is normal - embedded_svc only exists after user clicks chat button');
                console.log('⚠️ Use console context for manual entry if needed');
            }
        } catch (error) {
            console.log('⚠️ Error in prechat configuration:', error.message);
            console.log('⚠️ Stack:', error.stack);
        }
    }

    

    async handleSendMessage(customValue) {
        // THE FIX: Grab the value directly from the input element to beat the race condition
        //const inputElement = this.template.querySelector('input');
        //const messageText = inputElement ? inputElement.value : this.userInput;
        //const messageText = customValue || (inputElement ? inputElement.value : this.userInput);
        
        // 1. Detect if 'customValue' is a browser event (from icon click) or a string (from a chip)
        const isEvent = customValue && (customValue instanceof Event || (customValue.type && customValue.target));
        const messageText = (customValue && !isEvent) ? customValue : (this.template.querySelector('input')?.value || this.userInput);

        //console.log('--- ATTEMPTING SEND ---');
        //console.log('ID:', this.vehicle?.vehicleAssetId);
        //console.log('Message:', messageText);
        
        // 2. Guard Clause
        if (!messageText || messageText.trim() === '') return;

        // 3. UI Updates
        this.addMessage(messageText, 'user');
        
        // Clear both the variable and the actual DOM element
        this.userInput = '';
        const inputElement = this.template.querySelector('input');
        if (inputElement) inputElement.value = '';
        //if (!this.userInput || this.userInput.trim() === '') return;

        //const messageText = this.userInput;
        //this.addMessage(messageText, 'user');
        //this.userInput = '';
        this.isTyping = true;

        try {
                const result = await sendMessageToAgent({
                    userMessage: messageText || '',
                    vehicleName: this.vehicle?.title || '',
                    city: this.city || '',
                    sessionId: this.currentSessionId || '',
                    vehicleAssetId: this.vehicle?.vehicleAssetId || '',
                    lat: this.lat ? String(this.lat) : '',
                    lon: this.lon ? String(this.lon) : '',
                    zipCode: this.zipCode || '' 
                });

                this.currentSessionId = result.sessionId;

                // THE FIX: Detect if the result contains "Choices"
                let rawAnswer = result.answer;

                // --- NEW: INTERCEPT AGENT ERRORS HIDDEN IN STRINGS ---
                // This catches the error from your Apex else block before it renders
                if (rawAnswer && (rawAnswer.includes('SessionAlreadyEndedException') || rawAnswer.includes('410'))) {
                    this.isSessionActive = false;
                    this.addMessage("This conversation has safely concluded. Please start a new session if you have more questions about the Electra series!", 
                    'agent');
                    this.isTyping = false;
                    return; // EXIT EARLY - Prevent further parsing
                }
                
                // DEBUG LOG: This will now definitely show up in your console
                //console.log('DEBUG - Agent raw output:', rawAnswer);

                let cleanText = '';
                let options = [];
                let slotOptions = [];
                let isSlotResponse = false;
                
                // 4. THE UNIVERSAL UNWRAPPER (Handles JSON wrappers)
                let innerContent = rawAnswer;
                //if (rawAnswer && rawAnswer.startsWith('{')) {
                try {
                    if (rawAnswer && rawAnswer.trim().startsWith('{')) {
                        //try {
                            const parsed = JSON.parse(rawAnswer);
                            if (parsed.type === 'Choices') {
                                options = parsed.value || []; // Native Agentforce Chips
                                cleanText = "Please select an option:";
                                innerContent = ""; // No further parsing needed
                            } 
                            else {
                                innerContent = parsed.value || rawAnswer;
                                cleanText = innerContent;
                            }
                        } else {
                            cleanText = rawAnswer;
                        }
                    } catch (e) { 
                        console.warn('Outer parse failed, using raw text.');
                        cleanText = rawAnswer;
                    }
                //} else {
                //    cleanText = rawAnswer;
                //}

                //this.addMessage(agentText, 'agent', options);


                //5. THE PARSER A: This looks for the BUTTONS in your screenshot
                if (innerContent && innerContent.includes('BUTTONS:')) {
                    const parts = innerContent.split('BUTTONS:');
                    //cleanText = parts[0].trim(); // Takes: "Sure! Here are the available models..."
                    if (cleanText.includes('BUTTONS:')) {
                        cleanText = cleanText.split('BUTTONS:')[0].trim();
                    }
            
                    // Regex to find the content inside [ ]
                    const match = parts[1].match(/\[(.*?)\]/);
                    if (match && match[1]) {
                        // Split the car names by comma and clean up whitespace
                        //options = match[1].split(',').map(opt => opt.trim());
                        // This ensures custom buttons take priority or append to native ones
                        const customOptions = match[1].split(',').map(opt => opt.trim());
                        options = [...new Set([...options, ...customOptions])];
                    }
                }

                //7. THE PARSER B: SLOTS PARSER - This looks for the bracketed JSON array the Apex is now sending
                if (innerContent && innerContent.includes('SLOTS:')) {
                    const parts = innerContent.split('SLOTS:');

                    // Ensure the chat bubble text doesn't show the SLOTS data
                    if (cleanText.includes('SLOTS:')) {
                        cleanText = cleanText.split('SLOTS:')[0].trim();
                    }

                    let arrayPart = parts[1].trim();
                    const startIdx = arrayPart.indexOf('[');
                
                    if (startIdx !== -1) {
                        arrayPart = arrayPart.substring(startIdx);
                    
                        // FIND THE END: If ] is missing (truncation), find the last valid }
                        let endIdx = arrayPart.lastIndexOf(']');
                        if (endIdx === -1) {
                            console.warn('⚠️ Slots data truncated by Agent. Attempting repair...');
                            endIdx = arrayPart.lastIndexOf('}');
                            if (endIdx !== -1) {
                                // Close the array at the last complete object
                                arrayPart = arrayPart.substring(0, endIdx + 1) + ']';
                            }
                        } else {
                            arrayPart = arrayPart.substring(0, endIdx + 1);
                        }

                        // Extract the JSON array from the brackets
                        //const jsonMatch = parts[1].match(/\[[\s\S]*\]/);
                        //if (jsonMatch) {
                        try { 
                            // Clean the extracted array string before final parsing
                            //let sanitizedArray = jsonMatch[0]
                            //.replace(/\\"/g, '"')  // Fix escaped quotes
                            //.replace(/\\n/g, '')   // Remove escaped newlines
                            //.trim();   // Remove literal newlines
                                    
                            // CRITICAL: Clean up escaped quotes if they exist
                            //const sanitizedJson = jsonMatch[0].replace(/\\"/g, '"').replace(/\\n/g, '');
                            const rawSlots = JSON.parse(arrayPart);
                                    
                            // Map the Apex names (slotDate/slotTime) to LWC names
                            slotOptions = rawSlots.map(item => ({
                                slotDate: item.slotDate,
                                slotTime: item.slotTime,
                                displayTime: item.displayTime
                            })).filter(item => item.slotDate && item.slotTime);
                            
                            if (slotOptions.length > 0) {
                                isSlotResponse = true;
                                console.log('✅ Slots parsed successfully: ', slotOptions.length);
                            }
                            
                        } catch (e) {
                                console.error('❌ Slot JSON Parse Error:', e.message);
                                console.log('Malformed Fragment:', arrayPart);
                        }

                        //}
                    } 

                }
                
                // 7. FINAL CLEANUP
                // Remove any remaining JSON artifacts like {"type":"Text"... if the unwrapper missed them
                /*if (cleanText.startsWith('{"')) {
                    cleanText = cleanText.split('":"').pop().replace('"}', '').replace(/\\n/g, '\n').trim();
                }*/
                cleanText = cleanText.replace(/\\n/g, '\n').replace(/\n\n$/, '').trim();

                // Proactive Session Close: Detect goodbye message
                if (cleanText.includes('Have a great day') || cleanText.includes('successfully booked') || cleanText.includes('confirmed')) {
                    // We keep the message, but disable the input for future typing
                    this.isSessionActive = false; 
                }

                // --- NEW: BOOKING CONFIRMATION BEAUTIFIER ---
                if (cleanText.includes('successfully booked!') && cleanText.includes('Booking ID:')) {
                    cleanText = cleanText
                        // 1. Add header break
                        .replace('Details:', 'Details are as follows.') 
                        // 2. Turn the dashes into bulleted new lines
                        .replace(/ - /g, '\n- ') 
                        // 3. Ensure the first detail starts on a new line
                        .replace('Details are as follows.- ', 'Details are as follows.\n- ')
                        // 4. Push the footer (WhatsApp message) down by two lines
                        .replace(' A confirmation message', '\n\nA confirmation message');
                    }
                // --------------------------------------------

                this.addMessage(cleanText, 'agent', options, isSlotResponse, slotOptions);
        
            } catch (error) {
                //let message = 'Unknown Error';
                //if (error.body && error.body.message) message = error.body.message;
                //else if (error.message) message = error.message;

                //console.error('REAL ERROR REVEALED:', message);
                //console.error('SERVER ERROR:', JSON.stringify(error));
                //console.log('Error Detail:', JSON.parse(JSON.stringify(error)));
                //this.addMessage("Agent Connection Error: " + (error.body?.message || error.message), 'agent');

                // --- NEW: SESSION EXPIRY HANDLER ---
                const errorString = JSON.stringify(error);
                const isExpired = errorString.includes('SessionAlreadyEndedException') || errorString.includes('410');
                if (isExpired) {
                    this.isSessionActive = false;
                    this.addMessage("This conversation has safely concluded. If you have more questions about the Electra series, please start a new session.", 'agent');
                } else {
                    this.addMessage("Connection Error: " + (error.body?.message || error.message), 'agent');
                }
                // ------------------------------------
            } finally {
                this.isTyping = false;
            }
    }

    // 3. Add a method to reset the chat
    handleRestartChat() {
        this.chatMessages = [];
        this.currentSessionId = null;
        this.isSessionActive = true;
        this.isBookingConfirmed = false;
        // Optional: Send an initial "Hi" to trigger the agent again
    }


    // Updated signature with default values
    addMessage(text, type, options = [], isSlotResponse = false, slotOptions = []){
        this.chatMessages = [...this.chatMessages, {
            id: Date.now(),
            text: text,
            type: type,
            options: options, // Store the buttons here
            isSlotResponse: isSlotResponse, // NEW: Flag to trigger c-electra-slot-picker
            slotOptions: slotOptions,       // NEW: The array of slot objects
            hasOptions: options.length > 0,
            bubbleClass: type === 'agent' ? 'msg-container agent' : 'msg-container user'
        }];
    }

    // New method to handle the chip click
    handleOptionClick(event) {
        const selectedOption = event.target.dataset.val;
        //this.userInput = selectedOption;
        this.handleSendMessage(selectedOption); // Auto-send the selection
    }

    // This handles the event from <c-electra-slot-picker>
    handleSlotSelection(event) {
        const selectedSlot = event.detail; // This is the 'displayTime' string
    
        // Automatically send the booking request to the agent
        this.handleSendMessage(`I would like to book the slot: ${selectedSlot}`);
    }

    // Add the lifecycle hook
    renderedCallback() {
        this.scrollToBottom();
    }

    // 2. Add the helper method
    scrollToBottom() {
        const viewport = this.template.querySelector('.chat-viewport');
        if (viewport) {
            // A 100ms delay ensures the new bubble is fully rendered 
            // and its height is included in the scroll calculation
            setTimeout(() => {
                viewport.scrollTo({
                    top: viewport.scrollHeight,
                    behavior: 'smooth' // Adds that professional sliding feel
                });
            }, 100);
        }
    }


}
