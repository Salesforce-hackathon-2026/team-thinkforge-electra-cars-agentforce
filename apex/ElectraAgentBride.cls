// CRITICAL: "without sharing" allows the Guest to trigger the Invocable Action
public without sharing class ElectraAgentBridge {
    
    // We target the Default Agent because it's the most stable for text-only headless UIs
    private static final String AGENT_API_NAME = 'ElectraCars_Test_Drive_Booking_Agent'; 
    
    @AuraEnabled
    public static Map<String, String> sendMessageToAgent(String userMessage, String vehicleName, String city, String sessionId, String vehicleAssetId, String lat, String lon, String zipCode) {
        try {
            // Ground the agent with the specific CMS Asset ID you found
            String contextualPrompt = 'Vehicle Asset ID: ' + vehicleAssetId + 
                                     '. Model: ' + vehicleName + 
                                     '. User Location: ' + (city != null ? city : 'Unknown') +
                                     ' (Lat: ' + (lat != null ? lat : 'N/A') + 
                                     ', Lon: ' + (lon != null ? lon : 'N/A') + 
                                     ', Zip: ' + (zipCode != null ? zipCode : 'N/A') + ')' + 
                                     '. Message: ' + userMessage;

            // Use the standard 2026 AI Agent type
            //Invocable.Action action = Invocable.Action.createStandardAction('aiAgent');
            Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', AGENT_API_NAME);
            
            action.setInvocationParameter('agentDeveloperName', AGENT_API_NAME);
            //action.setInvocationParameter('input', contextualPrompt);
            action.setInvocationParameter('userMessage', contextualPrompt);
            
            if (String.isNotBlank(sessionId)) {
                action.setInvocationParameter('sessionId', sessionId);
            }

            List<Invocable.Action.Result> results = action.invoke();
            Invocable.Action.Result result = results[0];

            Map<String, String> responseMap = new Map<String, String>();
            if (result.isSuccess()) {
                String rawAnswer = (String)result.getOutputParameters().get('agentResponse');
                String cleanAnswer = rawAnswer;

                // THE FIX: Parse the JSON to extract the "value" string
                try {
                    if (rawAnswer != null && rawAnswer.startsWith('{')) {
                        Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(rawAnswer);
                        // NEW LOGIC: Check the type of response from the Reasoning Engine
                        String responseType = (String)jsonMap.get('type');

                            /*if ('Choices'.equals(responseType)) {
                                // DO NOT UNWRAP. Send the whole JSON so the LWC can render chips.
                                cleanAnswer = rawAnswer; 
                            } else if (jsonMap.containsKey('value')) {
                                // It is just standard text, unwrap it to keep the UI clean
                                cleanAnswer = (String)jsonMap.get('value');
                            }*/

                            // THE FIX: If the response contains "SLOTS:", do NOT unwrap it. 
                            // We send the full JSON string to the LWC so the LWC Parser can find the hidden slots.
                            if ('Choices'.equals(responseType) || rawAnswer.contains('SLOTS:')) {
                                cleanAnswer = rawAnswer; 
                            } else if (jsonMap.containsKey('value')) {
                                cleanAnswer = (String)jsonMap.get('value');
                            }
                        
                        }
                    } catch (Exception e) {
                        // If it's not valid JSON, we just fall back to the raw string
                        cleanAnswer = rawAnswer;
                    }
                responseMap.put('answer', cleanAnswer);
                // For 'aiAgent' type, the output keys are 'response' and 'sessionId'
                // For 'generateAiAgentResponse' type, the output keys are 'agentResponse' and 'sessionId'
                //responseMap.put('answer', (String)result.getOutputParameters().get('agentResponse'));
                responseMap.put('sessionId', (String)result.getOutputParameters().get('sessionId'));
            } else {
                //responseMap.put('answer', 'Agent is thinking... but silent: ' + result.getErrors()[0].getMessage());
                // FIX: Throw an exception to trigger the JS .catch() block
                String errorMessage = result.getErrors()[0].getMessage();
                throw new AuraHandledException(errorMessage);
            }
            
            return responseMap;

        } catch (Exception e) {
            throw new AuraHandledException('Bridge Failure: ' + e.getMessage());
        }
    }
}
