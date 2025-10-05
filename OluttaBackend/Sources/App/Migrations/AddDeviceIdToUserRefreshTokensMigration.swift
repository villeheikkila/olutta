import PostgresMigrations
import PostgresNIO

struct AddDeviceIdToUserRefreshTokensMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            ALTER TABLE public.user_refresh_tokens
            ADD COLUMN device_id UUID NOT NULL;
            """,
            logger: logger,
        )
    }

    func revert(connection _: PostgresConnection, logger _: Logger) async throws {}
}
