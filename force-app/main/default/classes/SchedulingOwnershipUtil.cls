public with sharing class SchedulingOwnershipUtil {

    public static Id resolveHostUser(Id ownerUser, Id recordOwnerId) {
        return ownerUser != null ? ownerUser : recordOwnerId;
    }

    public static Boolean isOwnedByUser(Id ownerUser, Id recordOwnerId, Id userId) {
        return ownerUser == userId || (ownerUser == null && recordOwnerId == userId);
    }
}
