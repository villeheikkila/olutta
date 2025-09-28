import PostgresMigrations

func addDatabaseMigrations(to migrations: DatabaseMigrations) async {
    await migrations.add(AdoptHummingbirdMigrations())
    await migrations.add(ScheduleAvailabilityRefreshMigration())
    await migrations.add(AddDeviceTableMigration())
}
