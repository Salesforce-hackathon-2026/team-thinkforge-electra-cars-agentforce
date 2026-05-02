public with sharing class AF_TerritoryRoutingInvocable {

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;

        @InvocableVariable
        public String userLatitude;

        @InvocableVariable
        public String userLongitude;
    }

    public class Response {
        @InvocableVariable
        public String resultJson;
    }

    private static void busyWait(Integer milliseconds) {
        Long target = System.currentTimeMillis() + milliseconds;
        while (System.currentTimeMillis() < target) {}
    }

    private static Boolean hasCpuBudget(Integer waitMs) {
        return (Limits.getLimitCpuTime() - Limits.getCpuTime()) > (waitMs + 2000);
    }

    @InvocableMethod(label='Find Nearest Dealership Territory (5 to 50 km)')
    public static List<Response> route(List<Request> requests) {
        List<Response> results = new List<Response>();
        final List<Decimal> RADII = new List<Decimal>{ 5, 10, 20, 30, 40, 50 };
        final Integer LIMIT_SIZE  = 3; // always return top 3 nearest territories

        for (Request req : requests) {
            Response res = new Response();
            Map<String, Object> payload = new Map<String, Object>();

            try {
                Decimal lat = null;
                Decimal lon = null;

                // ── Priority 1: Valid user coordinates from website ──────────
                // Treat 0,0 as invalid (middle of ocean — agent default)
                Boolean hasValidUserCoords =
                    req.userLatitude  != null && req.userLatitude.trim().length()  > 0 &&
                    req.userLongitude != null && req.userLongitude.trim().length() > 0 &&
                    Decimal.valueOf(req.userLatitude.trim())  != 0 &&
                    Decimal.valueOf(req.userLongitude.trim()) != 0;

                if (hasValidUserCoords) {
                    lat = Decimal.valueOf(req.userLatitude.trim());
                    lon = Decimal.valueOf(req.userLongitude.trim());
                    System.debug('Using user coords: ' + lat + ', ' + lon);

                } else {
                    // ── Priority 2: Lead geocoded coordinates ────────────────
                    System.debug('User coords invalid/0,0 — using Lead geocode');

                    Lead l = [
                        SELECT Id, PostalCode, Latitude, Longitude
                        FROM Lead
                        WHERE Id = :req.leadId
                        LIMIT 1
                    ];

                    if (l.Latitude == null && l.PostalCode == null) {
                        payload.put('status',       'ERROR');
                        payload.put('found',        false);
                        payload.put('errorMessage', 'No valid coordinates and Lead has no address.');
                        res.resultJson = JSON.serialize(payload);
                        results.add(res);
                        continue;
                    }

                    lat = l.Latitude;
                    lon = l.Longitude;

                    // ── Geocode retry loop ───────────────────────────────────
                    final Integer WAIT_MS   = 500;
                    final Integer MAX_RETRY = 2;
                    Integer retryCount = 0;

                    while ((lat == null || lon == null)
                            && retryCount < MAX_RETRY
                            && hasCpuBudget(WAIT_MS)) {
                        busyWait(WAIT_MS);
                        retryCount++;
                        l = [SELECT Id, Latitude, Longitude FROM Lead WHERE Id = :req.leadId LIMIT 1];
                        lat = l.Latitude;
                        lon = l.Longitude;
                    }

                    if (lat == null || lon == null) {
                        payload.put('status',       'PENDING_GEOCODE');
                        payload.put('found',        false);
                        payload.put('errorMessage', 'Geocoding did not complete after '
                            + retryCount + ' retries. Please retry.');
                        res.resultJson = JSON.serialize(payload);
                        results.add(res);
                        continue;
                    }

                    System.debug('Using Lead coords: ' + lat + ', ' + lon);
                }

                // ── Search territories ───────────────────────────────────────
                List<ServiceTerritory> sts = new List<ServiceTerritory>();
                Decimal chosenRadius;

                for (Decimal radiusKm : RADII) {
                    sts = [
                        SELECT Id, Name,
                               DISTANCE(Address, GEOLOCATION(:lat, :lon), 'km') distKm
                        FROM ServiceTerritory
                        WHERE IsActive = true
                          AND DISTANCE(Address, GEOLOCATION(:lat, :lon), 'km') < :radiusKm
                        ORDER BY DISTANCE(Address, GEOLOCATION(:lat, :lon), 'km')
                        LIMIT :LIMIT_SIZE
                    ];
                    if (!sts.isEmpty()) {
                        chosenRadius = radiusKm;
                        break;
                    }
                }

                if (sts.isEmpty()) {
                    payload.put('status',       'NOT_FOUND');
                    payload.put('found',        false);
                    payload.put('radiusUsedKm', 50);
                    payload.put('errorMessage', 'No dealership found within 50 km.');
                    res.resultJson = JSON.serialize(payload);
                    results.add(res);
                    continue;
                }

                // ── Build response ───────────────────────────────────────────
                List<Map<String, Object>> options = new List<Map<String, Object>>();
                for (ServiceTerritory st : sts) {
                    options.add(new Map<String, Object>{
                        'territoryId'   => st.Id,
                        'territoryName' => st.Name,
                        'distanceKm'    => (Decimal) st.get('distKm')
                    });
                }

                payload.put('status',            'SUCCESS');
                payload.put('found',             true);
                payload.put('radiusUsedKm',      chosenRadius);
                payload.put('bestTerritoryId',   options[0].get('territoryId'));
                payload.put('bestTerritoryName', options[0].get('territoryName'));
                payload.put('bestDistanceKm',    options[0].get('distanceKm'));
                payload.put('options',           options);

            } catch (Exception e) {
                payload.put('status',       'ERROR');
                payload.put('found',        false);
                payload.put('errorMessage', e.getMessage());
            }

            res.resultJson = JSON.serialize(payload);
            results.add(res);
        }

        return results;
    }
}
