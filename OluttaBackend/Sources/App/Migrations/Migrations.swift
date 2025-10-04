import PostgresMigrations

let allMigrations: [DatabaseMigration] = [
    AdoptHummingbirdMigrations(),
    ScheduleAvailabilityRefreshMigration(),
    AddDeviceTableMigration(),
    AddPushNotificationSubscriptionTableMigration(),
    CreateUsersTableMigration(),
    AddUserRefreshTokensMigration()
]
