import PostgresMigrations
import PostgresNIO

struct CreateDeviceTableMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.devices (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                push_notification_token TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_devices_push_notification_token 
            ON public.devices (push_notification_token) 
            WHERE push_notification_token IS NOT NULL;
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE OR REPLACE FUNCTION fnc__update_updated_at_column()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ language 'plpgsql';
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_updated_at 
                BEFORE UPDATE ON public.devices 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            DROP TRIGGER IF EXISTS tg__update_updated_at ON public.devices;
            DROP FUNCTION IF EXISTS fnc__update_updated_at_column();
            DROP INDEX IF EXISTS idx_devices_refresh_token_id;
            DROP INDEX IF EXISTS idx_devices_push_notification_token;
            DROP TABLE IF EXISTS public.devices;
            """,
            logger: logger,
        )
    }
}
