public with sharing class TeamSchedulingService {

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
            if (!isHostAvailable(host.User__c, slotStart, slotEnd)) {
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
            if (!isHostAvailable(hostId, slotStart, slotEnd)) {
                return false;
            }
        }
        return true;
    }

    public static List<AvailabilityService.TimeSlot> getCollectiveAvailableSlots(
        Id eventTypeId, Date startDate, Date endDate
    ) {
        Event_Type__c eventType = [
            SELECT Id, Duration_Minutes__c, Min_Booking_Notice_Minutes__c,
                   Buffer_Before_Minutes__c, Buffer_After_Minutes__c,
                   Slot_Interval_Minutes__c, Schedule__c, Owner_User__c
            FROM Event_Type__c
            WHERE Id = :eventTypeId
            WITH USER_MODE
            LIMIT 1
        ];

        List<Id> hostIds = getCollectiveHosts(eventTypeId);
        if (hostIds.isEmpty()) {
            return new List<AvailabilityService.TimeSlot>();
        }

        List<AvailabilityService.TimeSlot> candidateSlots =
            AvailabilityService.getAvailableSlots(eventTypeId, startDate, endDate);

        List<AvailabilityService.TimeSlot> collectiveSlots = new List<AvailabilityService.TimeSlot>();
        for (AvailabilityService.TimeSlot slot : candidateSlots) {
            Boolean allFree = true;
            for (Id hostId : hostIds) {
                if (!isHostAvailable(hostId, slot.startTime, slot.endTime)) {
                    allFree = false;
                    break;
                }
            }
            if (allFree) {
                collectiveSlots.add(slot);
            }
        }
        return collectiveSlots;
    }

    private static Boolean isHostAvailable(Id userId, Datetime slotStart, Datetime slotEnd) {
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
            WITH USER_MODE
            LIMIT 1
        ];

        return oooEntries.isEmpty();
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
