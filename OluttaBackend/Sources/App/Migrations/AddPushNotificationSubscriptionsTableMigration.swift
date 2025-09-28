import PostgresMigrations
import PostgresNIO

struct AddPushNotificationSubscriptionTableMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.push_notification_subscription (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                device_id UUID NOT NULL REFERENCES public.device(id) ON DELETE CASCADE,
                store_id UUID NOT NULL REFERENCES public.stores_alko(id) ON DELETE CASCADE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                CONSTRAINT uq__device_id__store_id UNIQUE (device_id, store_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_push_notification_subscription_updated_at
                BEFORE UPDATE ON public.push_notification_subscription
                FOR EACH ROW
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            DROP TRIGGER IF EXISTS tg__update_push_notification_subscription_updated_at ON public.push_notification_subscription;
            DROP TABLE IF EXISTS public.push_notification_subscription;
            """,
            logger: logger,
        )
    }
}
