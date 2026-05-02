public with sharing class AF_WeatherInvocable {

    public class Request {
        @InvocableVariable(required=true)
        public Id territoryId;

        @InvocableVariable(required=true)
        public String slotDate; // YYYY-MM-DD format e.g. "2026-04-27"
    }

    public class Response {
        @InvocableVariable public String status;          // SUCCESS | NO_COORDS | NO_DATA | ERROR
        @InvocableVariable public String errorMessage;
        @InvocableVariable public String weatherSummary; // ready-to-use string for agent
    }

    /*
     * Maps WMO weather codes to human readable condition and emoji.
     * Reference: https://open-meteo.com/en/docs#weathervariables
     */
    private static Map<Integer, String> WMO_CONDITION = new Map<Integer, String>{
        0  => 'Clear Sky',
        1  => 'Mainly Clear',
        2  => 'Partly Cloudy',
        3  => 'Overcast',
        45 => 'Foggy',
        48 => 'Foggy',
        51 => 'Light Drizzle',
        53 => 'Moderate Drizzle',
        55 => 'Dense Drizzle',
        61 => 'Slight Rain',
        63 => 'Moderate Rain',
        65 => 'Heavy Rain',
        71 => 'Slight Snow',
        73 => 'Moderate Snow',
        75 => 'Heavy Snow',
        80 => 'Slight Showers',
        81 => 'Moderate Showers',
        82 => 'Violent Showers',
        95 => 'Thunderstorm',
        96 => 'Thunderstorm with Hail',
        99 => 'Thunderstorm with Heavy Hail'
    };

    private static Map<Integer, String> WMO_EMOJI = new Map<Integer, String>{
        0  => '☀️',
        1  => '🌤',
        2  => '⛅',
        3  => '☁️',
        45 => '🌫',
        48 => '🌫',
        51 => '🌦',
        53 => '🌦',
        55 => '🌧',
        61 => '🌧',
        63 => '🌧',
        65 => '🌧',
        71 => '🌨',
        73 => '🌨',
        75 => '❄️',
        80 => '🌦',
        81 => '🌧',
        82 => '⛈',
        95 => '⛈',
        96 => '⛈',
        99 => '⛈'
    };

    /*
     * Returns a driving-context message based on rain probability.
     * Used to make the agent response feel natural and helpful.
     */
    private static String getDrivingContext(Integer rainProb, Integer weatherCode) {
        if (rainProb >= 70) {
            return 'You may want to bring an umbrella.';
        } else if (rainProb >= 40) {
            return 'There is a slight chance of rain.';
        } else if (rainProb == 0 && weatherCode <= 2) {
            return 'Perfect weather for a test drive! 🚗';
        } else {
            return 'Good conditions for a test drive.';
        }
    }

    @InvocableMethod(label='Get Weather for Dealer Territory')
    public static List<Response> getWeather(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            try {
                // ── Step 1: Get lat/lon from ServiceTerritory ────────────────
                List<ServiceTerritory> territories = [
                    SELECT Id, Name, Latitude, Longitude
                    FROM ServiceTerritory
                    WHERE Id = :req.territoryId
                    LIMIT 1
                ];

                if (territories.isEmpty()) {
                    res.status       = 'ERROR';
                    res.errorMessage = 'Territory not found for Id: ' + req.territoryId;
                    results.add(res);
                    continue;
                }

                ServiceTerritory st = territories[0];

                if (st.Latitude == null || st.Longitude == null) {
                    res.status       = 'NO_COORDS';
                    res.errorMessage = 'Territory ' + st.Name
                        + ' has no geocoded coordinates. '
                        + 'Re-save the territory record to trigger geocoding.';
                    results.add(res);
                    continue;
                }

                System.debug('TERRITORY → ' + st.Name
                    + ' | Lat: ' + st.Latitude
                    + ' | Lon: ' + st.Longitude);

                // ── Step 2: Build Open-Meteo API URL ─────────────────────────
                String latStr      = String.valueOf(st.Latitude);
                String lonStr      = String.valueOf(st.Longitude);
                String slotDateStr = req.slotDate;

                String url =
                    'https://api.open-meteo.com/v1/forecast'
                    + '?latitude='   + latStr
                    + '&longitude='  + lonStr
                    + '&daily=temperature_2m_max,temperature_2m_min'
                    + ',precipitation_probability_max,weathercode'
                    + '&timezone=Asia/Kolkata'
                    + '&start_date=' + slotDateStr
                    + '&end_date='   + slotDateStr;

                System.debug('OPEN-METEO URL → ' + url);

                // ── Step 3: Call Open-Meteo API ──────────────────────────────
                Http http           = new Http();
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(url);
                httpReq.setMethod('GET');
                httpReq.setTimeout(10000);

                HttpResponse httpRes = http.send(httpReq);

                System.debug('RESPONSE CODE → ' + httpRes.getStatusCode());
                System.debug('RESPONSE BODY → ' + httpRes.getBody());

                if (httpRes.getStatusCode() != 200) {
                    res.status       = 'ERROR';
                    res.errorMessage = 'Open-Meteo API returned status: '
                        + httpRes.getStatusCode();
                    results.add(res);
                    continue;
                }

                // ── Step 4: Parse response ───────────────────────────────────
                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());

                Map<String, Object> daily =
                    (Map<String, Object>) body.get('daily');

                if (daily == null) {
                    res.status       = 'NO_DATA';
                    res.errorMessage = 'No daily weather data returned for date: '
                        + slotDateStr;
                    results.add(res);
                    continue;
                }

                List<Object> tempMaxList = (List<Object>) daily.get('temperature_2m_max');
                List<Object> tempMinList = (List<Object>) daily.get('temperature_2m_min');
                List<Object> rainList    = (List<Object>) daily.get('precipitation_probability_max');
                List<Object> codeList    = (List<Object>) daily.get('weathercode');

                if (tempMaxList == null || tempMaxList.isEmpty()) {
                    res.status       = 'NO_DATA';
                    res.errorMessage = 'Weather data is empty for date: ' + slotDateStr;
                    results.add(res);
                    continue;
                }

                // ── Step 5: Extract values as local variables ────────────────
                Decimal tempMax         = Decimal.valueOf(String.valueOf(tempMaxList[0]));
                Decimal tempMin         = Decimal.valueOf(String.valueOf(tempMinList[0]));
                Integer rainProbability = Integer.valueOf(String.valueOf(rainList[0]));
                Integer weatherCode     = Integer.valueOf(String.valueOf(codeList[0]));

                // ── Step 6: Resolve condition and emoji as local variables ────
                String condition    = WMO_CONDITION.containsKey(weatherCode)
                    ? WMO_CONDITION.get(weatherCode)
                    : 'Unknown (' + weatherCode + ')';

                String weatherEmoji = WMO_EMOJI.containsKey(weatherCode)
                    ? WMO_EMOJI.get(weatherCode)
                    : '🌡';

                // ── Step 7: Build weather summary string for agent ───────────
                String drivingContext = getDrivingContext(rainProbability, weatherCode);

                res.weatherSummary =
                    weatherEmoji + ' Weather in ' + st.Name
                    + ' on ' + slotDateStr + ': '
                    + tempMin + '–' + tempMax + '°C, '
                    + condition + ', '
                    + rainProbability + '% chance of rain. '
                    + drivingContext;

                System.debug('WEATHER SUMMARY → ' + res.weatherSummary);

                res.status = 'SUCCESS';

            } catch (Exception e) {
                res.status       = 'ERROR';
                res.errorMessage = e.getMessage();
                System.debug('EXCEPTION: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
            }

            results.add(res);
        }

        return results;
    }
}
