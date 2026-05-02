/**
 * AF_GetDealerSlotsInvocable
 *
 * Finds available test drive slots using direct SOQL queries.
 *
 * WHY NO LxScheduler:
 * - LxScheduler requires Salesforce Scheduler license on the running user
 * - Einstein Agent Service Agent user cannot hold this license
 * - This SOQL-based approach has zero license dependency
 * - Works with any user that has basic Read permissions
 *
 * OBJECTS REQUIRED (Read access in Einstein Agent Permission Set):
 * - WorkType
 * - ServiceTerritory
 * - ServiceTerritoryMember
 * - ServiceResource
 * - TimeSlot
 * - ServiceAppointment
 * - ResourceAbsence
 *
 * SHARING RULES REQUIRED (for Einstein Agent user visibility):
 * - ServiceTerritory    → All Internal Users → Read Only
 * - ServiceAppointment  → All Internal Users → Read Only
 * - WorkType            → All Internal Users → Read Only
 * - ServiceResource     → All Internal Users → Read Only
 */
public with sharing class AF_GetDealerSlotsInvocable {

    public class Request {
        @InvocableVariable(required=true)
        public Id territoryId;

        @InvocableVariable(required=true)
        public Id workTypeId;

        @InvocableVariable
        public Integer daysAhead; // default 7

        @InvocableVariable
        public Integer maxSlots;  // default 100
    }

    public class SlotOption {
        @InvocableVariable public String displayTime; // "Tue 28 Apr, 9:00 AM - 10:00 AM IST"
        @InvocableVariable public String slotDate;    // "2026-04-28"
        @InvocableVariable public String slotTime;    // "9:00 AM - 10:00 AM"
    }

    public class Response {
        @InvocableVariable public String           status;       // SUCCESS | NO_SLOTS | ERROR
        @InvocableVariable public String           errorMessage;
        @InvocableVariable public Integer          totalSlots;
        @InvocableVariable public List<SlotOption> slots;
        @InvocableVariable public Id               territoryId;
        @InvocableVariable public Id               ServiceresourceId;
        @InvocableVariable public String           ServiceresourceName;
        @InvocableVariable public String           formattedJsonSlots;
    }

    @InvocableMethod(label='Get Available Test Drive Slots for Territory')
    public static List<Response> getSlots(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res    = new Response();
            res.slots       = new List<SlotOption>();
            res.territoryId = req.territoryId;

            try {
                Integer daysAhead = (req.daysAhead == null || req.daysAhead <= 0) ? 7   : req.daysAhead;
                Integer maxSlots  = (req.maxSlots  == null || req.maxSlots  <= 0) ? 100 : req.maxSlots;

                // ── Step 1: Get WorkType duration ────────────────────────────
                List<WorkType> wts = [
                    SELECT Id, DurationInMinutes
                    FROM WorkType
                    WHERE Id = :req.workTypeId
                    LIMIT 1
                ];
                if (wts.isEmpty()) {
                    res.status       = 'ERROR';
                    res.errorMessage = 'WorkType not found: ' + req.workTypeId;
                    results.add(res);
                    continue;
                }
                Integer durationMins = Integer.valueOf(wts[0].DurationInMinutes);
                System.debug('Duration: ' + durationMins + ' mins');

                // ── Step 2: Get primary rep for display name ─────────────────
                List<ServiceTerritoryMember> primaryMember = [
                    SELECT ServiceResourceId, ServiceResource.Name
                    FROM ServiceTerritoryMember
                    WHERE ServiceTerritoryId = :req.territoryId
                      AND ServiceResource.IsActive = true
                      AND ServiceResource.ResourceType = 'T'
                      AND (EffectiveEndDate = null OR EffectiveEndDate >= TODAY)
                    LIMIT 1
                ];
                if (primaryMember.isEmpty()) {
                    res.status       = 'NO_SLOTS';
                    res.errorMessage = 'No active sales rep found for this territory.';
                    results.add(res);
                    continue;
                }
                res.ServiceresourceName = primaryMember[0].ServiceResource.Name;
                res.ServiceresourceId   = primaryMember[0].ServiceResourceId;
                Id resourceId    = primaryMember[0].ServiceResourceId;
                System.debug('Rep: ' + res.ServiceresourceName);

                // ── Step 3: Get Operating Hours for territory ────────────────
                List<ServiceTerritory> sts = [
                    SELECT Id, OperatingHoursId
                    FROM ServiceTerritory
                    WHERE Id = :req.territoryId
                    LIMIT 1
                ];
                if (sts.isEmpty() || sts[0].OperatingHoursId == null) {
                    res.status       = 'NO_SLOTS';
                    res.errorMessage = 'No operating hours configured for this territory.';
                    results.add(res);
                    continue;
                }

                // ── Step 4: Get TimeSlots from Operating Hours ───────────────
                // Supports multiple shifts per day e.g. 9AM-1PM and 3PM-6PM
                List<TimeSlot> timeSlots = [
                    SELECT DayOfWeek, StartTime, EndTime
                    FROM TimeSlot
                    WHERE OperatingHoursId = :sts[0].OperatingHoursId
                    ORDER BY DayOfWeek, StartTime
                ];
                if (timeSlots.isEmpty()) {
                    res.status       = 'NO_SLOTS';
                    res.errorMessage = 'No time slots defined in operating hours.';
                    results.add(res);
                    continue;
                }
                System.debug('TimeSlots: ' + timeSlots.size());

                // ── Step 5: Get booked ServiceAppointments ───────────────────
                // Excludes Canceled, Cannot Complete, Completed
                // Blocks: None, Scheduled, Dispatched, In Progress, Checked In
                DateTime searchStart = DateTime.now();
                DateTime searchEnd   = DateTime.now().addDays(daysAhead);

                List<ServiceAppointment> booked = [
                    SELECT SchedStartTime
                    FROM ServiceAppointment
                    WHERE ServiceTerritoryId = :req.territoryId
                      AND SchedStartTime >= :searchStart
                      AND SchedStartTime <= :searchEnd
                      AND Status NOT IN ('Canceled', 'Cannot Complete', 'Completed')
                    ORDER BY SchedStartTime
                ];
                System.debug('Booked: ' + booked.size());

                // ── Step 6: Get Resource Absences ────────────────────────────
                // Blocks slots when rep is on holiday/unavailable
                List<ResourceAbsence> absences = [
                    SELECT Start, End
                    FROM ResourceAbsence
                    WHERE ResourceId = :resourceId
                      AND Start <= :searchEnd
                      AND End   >= :searchStart
                ];
                System.debug('Absences: ' + absences.size());

                // ── Step 7: Build booked millis set ──────────────────────────
                Set<Long> bookedMillis = new Set<Long>();
                for (ServiceAppointment sa : booked) {
                    bookedMillis.add(sa.SchedStartTime.getTime());
                }

                // ── Step 8: Build absence intervals ──────────────────────────
                List<Long[]> absenceIntervals = new List<Long[]>();
                for (ResourceAbsence ra : absences) {
                    absenceIntervals.add(
                        new Long[]{ ra.Start.getTime(), ra.End.getTime() }
                    );
                }

                // ── Step 9: Build day-of-week map (multiple shifts/day) ──────
                Map<String, List<TimeSlot>> dayToSlots =
                    new Map<String, List<TimeSlot>>();
                for (TimeSlot ts : timeSlots) {
                    if (!dayToSlots.containsKey(ts.DayOfWeek)) {
                        dayToSlots.put(ts.DayOfWeek, new List<TimeSlot>());
                    }
                    dayToSlots.get(ts.DayOfWeek).add(ts);
                }

                // ── Step 10: Loop through days and generate slots ─────────────
                List<SlotOption> availableSlots = new List<SlotOption>();
                Date     today = Date.today();
                DateTime now   = DateTime.now();

                for (Integer i = 0; i <= daysAhead
                        && availableSlots.size() < maxSlots; i++) {

                    Date   checkDate = today.addDays(i);
                    String dayOfWeek = DateTime.newInstance(
                        checkDate, Time.newInstance(0, 0, 0, 0)
                    ).format('EEEE');

                    // Skip non-working days
                    if (!dayToSlots.containsKey(dayOfWeek)) continue;

                    // Loop through ALL shifts for this day
                    for (TimeSlot ts : dayToSlots.get(dayOfWeek)) {

                        // newInstance treats stored time as local (IST) correctly
                        DateTime slotStart = DateTime.newInstance(
                            checkDate, ts.StartTime
                        );
                        DateTime workEnd = DateTime.newInstance(
                            checkDate, ts.EndTime
                        );

                        System.debug('Shift: ' + slotStart.format('h:mm a')
                            + ' to ' + workEnd.format('h:mm a')
                            + ' | ' + dayOfWeek + ' ' + checkDate);

                        while (slotStart.addMinutes(durationMins) <= workEnd
                                && availableSlots.size() < maxSlots) {

                            DateTime currentEnd = slotStart.addMinutes(durationMins);

                            // Skip past slots
                            if (slotStart <= now) {
                                slotStart = currentEnd;
                                continue;
                            }

                            // Skip booked slots
                            if (bookedMillis.contains(slotStart.getTime())) {
                                System.debug('Booked: ' + slotStart.format('h:mm a'));
                                slotStart = currentEnd;
                                continue;
                            }

                            // Skip absence slots
                            Boolean inAbsence = false;
                            for (Long[] interval : absenceIntervals) {
                                if (slotStart.getTime() >= interval[0]
                                        && slotStart.getTime() < interval[1]) {
                                    inAbsence = true;
                                    break;
                                }
                            }
                            if (inAbsence) {
                                System.debug('Absent: ' + slotStart.format('h:mm a'));
                                slotStart = currentEnd;
                                continue;
                            }

                            // ✅ Slot is available — add it
                            SlotOption opt  = new SlotOption();
                            opt.displayTime = slotStart.format('EEE d MMM, h:mm a')
                                            + ' - ' + currentEnd.format('h:mm a')
                                            + ' IST';
                            opt.slotDate    = String.valueOf(checkDate);
                            opt.slotTime    = slotStart.format('h:mm a')
                                            + ' - ' + currentEnd.format('h:mm a');
                            availableSlots.add(opt);

                            slotStart = currentEnd;
                        }
                    }
                }

                // ── Step 11: Build response ───────────────────────────────────
                if (availableSlots.isEmpty()) {
                    res.status       = 'NO_SLOTS';
                    res.errorMessage = 'No available slots in the next '
                        + daysAhead + ' days.';
                    results.add(res);
                    continue;
                }

                res.slots      = availableSlots;
                res.totalSlots = availableSlots.size();
                res.status     = 'SUCCESS';
                System.debug('✅ Total slots: ' + res.totalSlots);

            } catch (Exception e) {
                res.status       = 'ERROR';
                res.errorMessage = e.getMessage();
                System.debug('EXCEPTION: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
            }

            res.formattedJsonSlots = JSON.serialize(res.slots);
            results.add(res);
        }

        return results;
    }
}
