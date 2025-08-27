import PostgresMigrations
import PostgresNIO

struct AddDeviceTableMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.device (
                id UUID PRIMARY KEY,
                push_notification_token TEXT,
                is_sandbox BOOLEAN NOT NULL DEFAULT false,
                token_id TEXT,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
            );
            """,
            logger: logger
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
            logger: logger
        )
        
        try await connection.query(
            """
            CREATE TRIGGER tg__update_device_updated_at 
                BEFORE UPDATE ON public.device 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            DROP TRIGGER IF EXISTS tg__update_device_updated_at ON public.device;
            DROP FUNCTION IF EXISTS fnc__update_updated_at_column();
            DROP TABLE IF EXISTS public.device CASCADE;
            """,
            logger: logger
        )
    }
}
