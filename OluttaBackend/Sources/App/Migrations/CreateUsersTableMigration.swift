import PostgresMigrations
import PostgresNIO

struct CreateUsersTableMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            DROP TRIGGER IF EXISTS tg__update_push_notification_subscription_updated_at ON public.push_notification_subscription;
            """,
            logger: logger,
        )

        try await connection.query(
            """
            DROP TABLE IF EXISTS public.push_notification_subscription;
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.users (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
            );
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
            CREATE TRIGGER tg__update_users_updated_at 
                BEFORE UPDATE ON public.users 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.user_devices (
                id SERIAL PRIMARY KEY,
                user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
                device_id TEXT NOT NULL,
                token_id UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
                push_notification_token TEXT,
                expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                revoked_at TIMESTAMP WITH TIME ZONE NULL
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_devices_device_id ON public.user_devices(device_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_devices_token_id ON public.user_devices(token_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_devices_expires_at ON public.user_devices(expires_at);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_devices_user_device ON public.user_devices(user_id, device_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_user_devices_updated_at 
                BEFORE UPDATE ON public.user_devices 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.device_push_notification_subscription (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                device_id INTEGER NOT NULL REFERENCES public.user_devices(id) ON DELETE CASCADE,
                store_id UUID NOT NULL REFERENCES public.stores_alko(id) ON DELETE CASCADE,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                CONSTRAINT uq__device_id__store_id UNIQUE (device_id, store_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_push_notification_subscription_updated_at
                BEFORE UPDATE ON public.device_push_notification_subscription
                FOR EACH ROW
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )
    }

    func revert(connection _: PostgresConnection, logger _: Logger) async throws {}
}
