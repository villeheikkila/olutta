import PostgresMigrations
import PostgresNIO

struct AddUserRefreshTokensMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.user_refresh_tokens (
                id SERIAL PRIMARY KEY,
                user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
                refresh_token_id UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
                expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                revoked_at TIMESTAMP WITH TIME ZONE NULL
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_refresh_tokens_user_id ON public.user_refresh_tokens(user_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_refresh_tokens_refresh_token_id ON public.user_refresh_tokens(refresh_token_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_refresh_tokens_expires_at ON public.user_refresh_tokens(expires_at);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_user_refresh_tokens_updated_at 
                BEFORE UPDATE ON public.user_refresh_tokens 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )

        try await connection.query(
            """
            DROP INDEX IF EXISTS public.idx_user_devices_token_id;
            """,
            logger: logger,
        )

        try await connection.query(
            """
            ALTER TABLE public.user_devices DROP COLUMN IF EXISTS token_id;
            """,
            logger: logger,
        )
    }

    func revert(connection _: PostgresConnection, logger _: Logger) async throws {}
}
