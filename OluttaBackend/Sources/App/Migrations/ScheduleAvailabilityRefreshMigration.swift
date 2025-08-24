import PostgresMigrations
import PostgresNIO

struct ScheduleAvailabilityRefreshMigration: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            CREATE OR REPLACE FUNCTION fnc__schedule_all_products_refresh()
            RETURNS INTEGER
            LANGUAGE plpgsql
            AS $$
            DECLARE
                product_record RECORD;
                current_index INTEGER := 0;
                total_scheduled INTEGER := 0;
            BEGIN
                FOR product_record IN 
                    SELECT id FROM public.products_alko ORDER BY id
                LOOP
                    PERFORM pgmq.send(
                        queue_name => 'alko',
                        msg => '{"type": "v1:refresh-availability", "id": ' || product_record.id || '}',
                        delay => current_index * 3
                    );

                    current_index := current_index + 1;
                    total_scheduled := total_scheduled + 1;
                END LOOP;

                RETURN total_scheduled;
            END $$;
            """,
            logger: logger,
        )
        try await connection.query(
            """
            CREATE EXTENSION pg_cron
            """,
            logger: logger,
        )
        try await connection.query(
            """
            SELECT cron.schedule(
                'daily-alko-refresh',
                '0 8 * * *',
                'SELECT fnc__schedule_all_products_refresh();'
            );
            """,
            logger: logger,
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            """
            DROP FUNCTION IF EXISTS fnc__schedule_all_products_refresh();
            SELECT cron.unschedule('daily-alko-refresh');
            """,
            logger: logger,
        )
    }
}
