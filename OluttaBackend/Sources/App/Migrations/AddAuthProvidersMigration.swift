import PostgresMigrations
import PostgresNIO

struct AddAuthProvidersMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.auth_providers (
                id TEXT PRIMARY KEY
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            INSERT INTO public.auth_providers (id)
            VALUES ('sign_in_with_apple')
            ON CONFLICT (id) DO NOTHING;
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE IF NOT EXISTS public.user_auth_providers (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
                auth_provider_id TEXT NOT NULL REFERENCES public.auth_providers(id) ON DELETE CASCADE,
                external_id TEXT NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                UNIQUE(auth_provider_id, external_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_auth_providers_user_id ON public.user_auth_providers(user_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_auth_providers_auth_provider_id ON public.user_auth_providers(auth_provider_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE INDEX IF NOT EXISTS idx_user_auth_providers_external_id ON public.user_auth_providers(external_id);
            """,
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TRIGGER tg__update_user_auth_providers_updated_at 
                BEFORE UPDATE ON public.user_auth_providers 
                FOR EACH ROW 
                EXECUTE FUNCTION fnc__update_updated_at_column();
            """,
            logger: logger,
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {}
}
