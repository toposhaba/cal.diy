@IsTest
private class SchedulingOwnershipUtilTest {

    @IsTest
    static void testResolveHostUser() {
        Id userId = UserInfo.getUserId();
        System.assertEquals(userId, SchedulingOwnershipUtil.resolveHostUser(userId, userId));
        System.assertEquals(userId, SchedulingOwnershipUtil.resolveHostUser(null, userId));
    }

    @IsTest
    static void testIsOwnedByUser() {
        User otherUser = SchedulingTestDataFactory.createTestUser();
        Id userId = UserInfo.getUserId();
        System.assert(SchedulingOwnershipUtil.isOwnedByUser(userId, userId, userId));
        System.assert(SchedulingOwnershipUtil.isOwnedByUser(null, userId, userId));
        System.assert(!SchedulingOwnershipUtil.isOwnedByUser(null, otherUser.Id, userId));
    }
}
