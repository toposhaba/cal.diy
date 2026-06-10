public with sharing class TeamSchedulingService {

    public static Id resolveHostForBooking(Event_Type__c eventType, Datetime slotStart, Datetime slotEnd) {
        String schedulingType = normalizeSchedulingType(eventType.Scheduling_Type__c);

        if (schedulingType == 'Round_Robin') {
            return assignRoundRobinHost(eventType.Id, slotStart, slotEnd);
        }

        if (schedulingType == 'Collective') {
            if (!areAllHostsAvailable(eventType.Id, slotStart, slotEnd)) {
                throw new SchedulingException('SLOT_UNAVAILABLE', 'Not all hosts are available for the selected time');
            }
            return getPrimaryHostId(eventType);
        }

        if (schedulingType == 'Managed') {
            Id managedHost = getManagedHostId(eventType.Id);
            if (managedHost == null) {
                throw new SchedulingException('NO_HOSTS', 'No fixed host configured for this event type');
            }
            if (!isHostAvailableForSlot(managedHost, slotStart, slotEnd)) {
                throw new SchedulingException('SLOT_UNAVAILABLE', 'The assigned host is not available for the selected time');
            }
            return managedHost;
        }

        return SchedulingOwnershipUtil.resolveHostUser(eventType.Owner_User__c, eventType.OwnerId);
    }

    public static List<Id> resolveHostsForAvailability(Event_Type__c eventType) {
        String schedulingType = normalizeSchedulingType(eventType.Scheduling_Type__c);

        if (schedulingType == 'Round_Robin' || schedulingType == 'Collective') {
            List<Id> teamHosts = getCollectiveHosts(eventType.Id);
            if (!teamHosts.isEmpty()) {
                return teamHosts;
            }
        }

        if (schedulingType == 'Managed') {
            Id managedHost = getManagedHostId(eventType.Id);
            if (managedHost != null) {
                return new List<Id>{ managedHost };
            }
        }

        return new List<Id>{
            SchedulingOwnershipUtil.resolveHostUser(eventType.Owner_User__c, eventType.OwnerId)
        };
    }

    public static List<AvailabilityService.TimeSlot> getRoundRobinAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate
    ) {
        return getRoundRobinAvailableSlots(eventTypeId, startDate, endDate, null);
    }

    public static List<AvailabilityService.TimeSlot> getRoundRobinAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate, Integer durationMinutes
    ) {
        Event_Type__c eventType = getEventType(eventTypeId);
        List<Id> hostIds = resolveHostsForAvailability(eventType);
        if (hostIds.isEmpty()) {
            return new List<AvailabilityService.TimeSlot>();
        }

        Map<String, AvailabilityService.TimeSlot> slotMap = new Map<String, AvailabilityService.TimeSlot>();
        for (Id hostId : hostIds) {
            for (AvailabilityService.TimeSlot slot : AvailabilityService.getAvailableSlotsForHost(
                eventTypeId, hostId, startDate, endDate, durationMinutes
            )) {
                slotMap.put(buildSlotKey(slot.startTime, slot.endTime), slot);
            }
        }

        List<AvailabilityService.TimeSlot> slots = slotMap.values();
        slots.sort(new AvailabilityService.TimeSlotComparator());
        return slots;
    }

    public static Id assignRoundRobinHost(Id eventTypeId, Datetime slotStart, Datetime slotEnd) {
        List<Event_Type_Host__c> hosts = [
            SELECT Id, User__c, Priority__c, Weight__c, Schedule__c
            FROM Event_Type_Host__c
            WHERE Event_Type__c = :eventTypeId
            WITH USER_MODE
            ORDER BY Priority__c DESC, Weight__c DESC
        ];

        if (hosts.isEmpty()) {
            throw new SchedulingException('NO_HOSTS', 'No hosts configured for this event type');
        }

        Map<Id, Integer> recentBookingCounts = getRecentBookingCounts(eventTypeId, hosts);

        Id selectedHost = null;
        Decimal lowestWeightedLoad = null;

        for (Event_Type_Host__c host : hosts) {
            if (!isHostAvailableForSlot(host.User__c, slotStart, slotEnd)) {
                continue;
            }

            Integer bookingCount = recentBookingCounts.containsKey(host.User__c)
                ? recentBookingCounts.get(host.User__c) : 0;
            Decimal weight = host.Weight__c != null && host.Weight__c > 0 ? host.Weight__c : 100;
            Decimal weightedLoad = bookingCount / weight;

            if (lowestWeightedLoad == null || weightedLoad < lowestWeightedLoad) {
                lowestWeightedLoad = weightedLoad;
                selectedHost = host.User__c;
            }
        }

        if (selectedHost == null) {
            throw new SchedulingException('NO_AVAILABLE_HOSTS', 'No hosts are available for the selected time');
        }

        return selectedHost;
    }

    public static List<Id> getCollectiveHosts(Id eventTypeId) {
        List<Event_Type_Host__c> hosts = [
            SELECT Id, User__c, Is_Fixed__c
            FROM Event_Type_Host__c
            WHERE Event_Type__c = :eventTypeId
            WITH USER_MODE
        ];

        List<Id> hostIds = new List<Id>();
        for (Event_Type_Host__c host : hosts) {
            hostIds.add(host.User__c);
        }
        return hostIds;
    }

    public static Boolean areAllHostsAvailable(Id eventTypeId, Datetime slotStart, Datetime slotEnd) {
        List<Id> hostIds = getCollectiveHosts(eventTypeId);

        for (Id hostId : hostIds) {
            if (!isHostAvailableForSlot(hostId, slotStart, slotEnd)) {
                return false;
            }
        }
        return true;
    }

    public static Boolean isHostAvailableForSlot(Id userId, Datetime slotStart, Datetime slotEnd) {
        List<Booking__c> conflicts = [
            SELECT Id
            FROM Booking__c
            WHERE Host__c = :userId
                AND Status__c IN ('Accepted', 'Pending')
                AND Start_DateTime__c < :slotEnd
                AND End_DateTime__c > :slotStart
            WITH USER_MODE
            LIMIT 1
        ];

        if (!conflicts.isEmpty()) {
            return false;
        }

        List<Out_of_Office__c> oooEntries = [
            SELECT Id
            FROM Out_of_Office__c
            WHERE User__c = :userId
                AND Start_Date__c <= :slotStart.date()
                AND End_Date__c >= :slotEnd.date()
                AND (Status__c = 'Approved' OR Status__c = null)
            WITH USER_MODE
            LIMIT 1
        ];

        return oooEntries.isEmpty();
    }

    public static List<AvailabilityService.TimeSlot> getCollectiveAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate
    ) {
        return getCollectiveAvailableSlots(eventTypeId, startDate, endDate, null);
    }

    public static List<AvailabilityService.TimeSlot> getCollectiveAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate, Integer durationMinutes
    ) {
        Event_Type__c eventType = getEventType(eventTypeId);
        List<Id> hostIds = resolveHostsForAvailability(eventType);
        if (hostIds.isEmpty()) {
            return new List<AvailabilityService.TimeSlot>();
        }

        List<AvailabilityService.TimeSlot> collectiveSlots =
            AvailabilityService.getAvailableSlotsForHost(
                eventTypeId, hostIds[0], startDate, endDate, durationMinutes
            );

        for (Integer i = 1; i < hostIds.size(); i++) {
            List<AvailabilityService.TimeSlot> hostSlots = AvailabilityService.getAvailableSlotsForHost(
                eventTypeId, hostIds[i], startDate, endDate, durationMinutes
            );
            collectiveSlots = intersectTimeSlots(collectiveSlots, hostSlots);
        }

        return collectiveSlots;
    }

    public static void addCollectiveHostAttendees(Id bookingId, Id eventTypeId, Id primaryHostId) {
        List<Id> hostIds = getCollectiveHosts(eventTypeId);
        if (hostIds.size() <= 1) {
            return;
        }

        Set<Id> coHostIds = new Set<Id>(hostIds);
        coHostIds.remove(primaryHostId);

        Map<Id, User> coHosts = new Map<Id, User>([
            SELECT Id, Name, Email
            FROM User
            WHERE Id IN :coHostIds
            WITH USER_MODE
        ]);

        List<Attendee__c> attendees = new List<Attendee__c>();
        for (User coHost : coHosts.values()) {
            if (String.isNotBlank(coHost.Email)) {
                attendees.add(new Attendee__c(
                    Booking__c = bookingId,
                    Name = coHost.Name,
                    Email__c = coHost.Email
                ));
            }
        }

        if (!attendees.isEmpty()) {
            insert as user attendees;
        }
    }

    private static Event_Type__c getEventType(Id eventTypeId) {
        List<Event_Type__c> eventTypes = [
            SELECT Id, Owner_User__c, OwnerId, Scheduling_Type__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];
        if (eventTypes.isEmpty()) {
            throw new SchedulingException('EVENT_TYPE_NOT_FOUND', 'Event type not found');
        }
        return eventTypes[0];
    }

    private static Id getPrimaryHostId(Event_Type__c eventType) {
        List<Event_Type_Host__c> fixedHosts = [
            SELECT User__c
            FROM Event_Type_Host__c
            WHERE Event_Type__c = :eventType.Id AND Is_Fixed__c = true
            WITH USER_MODE
            ORDER BY Priority__c DESC NULLS LAST
            LIMIT 1
        ];
        if (!fixedHosts.isEmpty()) {
            return fixedHosts[0].User__c;
        }

        List<Id> hosts = getCollectiveHosts(eventType.Id);
        if (!hosts.isEmpty()) {
            return hosts[0];
        }

        return SchedulingOwnershipUtil.resolveHostUser(eventType.Owner_User__c, eventType.OwnerId);
    }

    private static Id getManagedHostId(Id eventTypeId) {
        List<Event_Type_Host__c> fixedHosts = [
            SELECT User__c
            FROM Event_Type_Host__c
            WHERE Event_Type__c = :eventTypeId AND Is_Fixed__c = true
            WITH USER_MODE
            ORDER BY Priority__c DESC NULLS LAST
            LIMIT 1
        ];
        return fixedHosts.isEmpty() ? null : fixedHosts[0].User__c;
    }

    private static String normalizeSchedulingType(String schedulingType) {
        return String.isBlank(schedulingType) ? 'Individual' : schedulingType;
    }

    private static List<AvailabilityService.TimeSlot> intersectTimeSlots(
        List<AvailabilityService.TimeSlot> leftSlots,
        List<AvailabilityService.TimeSlot> rightSlots
    ) {
        Map<String, AvailabilityService.TimeSlot> rightMap = new Map<String, AvailabilityService.TimeSlot>();
        for (AvailabilityService.TimeSlot slot : rightSlots) {
            rightMap.put(buildSlotKey(slot.startTime, slot.endTime), slot);
        }

        List<AvailabilityService.TimeSlot> intersection = new List<AvailabilityService.TimeSlot>();
        for (AvailabilityService.TimeSlot slot : leftSlots) {
            AvailabilityService.TimeSlot match = rightMap.get(buildSlotKey(slot.startTime, slot.endTime));
            if (match != null) {
                intersection.add(match);
            }
        }
        return intersection;
    }

    private static String buildSlotKey(Datetime startTime, Datetime endTime) {
        return String.valueOf(startTime.getTime()) + ':' + String.valueOf(endTime.getTime());
    }

    private static Map<Id, Integer> getRecentBookingCounts(Id eventTypeId, List<Event_Type_Host__c> hosts) {
        Set<Id> hostUserIds = new Set<Id>();
        for (Event_Type_Host__c h : hosts) {
            hostUserIds.add(h.User__c);
        }

        Datetime thirtyDaysAgo = Datetime.now().addDays(-30);
        List<AggregateResult> counts = [
            SELECT Host__c, COUNT(Id) cnt
            FROM Booking__c
            WHERE Event_Type__c = :eventTypeId
                AND Host__c IN :hostUserIds
                AND Status__c = 'Accepted'
                AND CreatedDate >= :thirtyDaysAgo
            WITH USER_MODE
            GROUP BY Host__c
        ];

        Map<Id, Integer> countMap = new Map<Id, Integer>();
        for (AggregateResult ar : counts) {
            countMap.put((Id) ar.get('Host__c'), (Integer) ar.get('cnt'));
        }
        return countMap;
    }
}
