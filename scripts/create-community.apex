PermissionSet bookerPerm = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Scheduling_Booker'
    LIMIT 1
];

List<User> guestUsers = [
    SELECT Id, Username
    FROM User
    WHERE UserType = 'Guest'
        AND IsActive = true
];

Integer assigned = 0;
for (User guest : guestUsers) {
    if ([
        SELECT Id
        FROM PermissionSetAssignment
        WHERE AssigneeId = :guest.Id AND PermissionSetId = :bookerPerm.Id
        LIMIT 1
    ].isEmpty()) {
        insert new PermissionSetAssignment(
            AssigneeId = guest.Id,
            PermissionSetId = bookerPerm.Id
        );
        assigned++;
    }
}

System.debug(
    'Scheduling_Booker assigned to ' + assigned + ' guest user(s). ' +
    'Set hostUserId on the community calendarBooking component to the host User Id.'
);
