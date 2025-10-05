import PostgresMigrations
import PostgresNIO

struct AdoptHummingbirdMigrations: DatabaseMigration {
    func apply(connection: PostgresConnection, logger: Logger) async throws {
        try await connection.query(
            "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.create('untappd');",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.create('alko');",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.create('alko_dlq');",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE stores_alko (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                store_external_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                address TEXT NOT NULL,
                city TEXT NOT NULL,
                postal_code TEXT NOT NULL,
                latitude DOUBLE PRECISION NOT NULL,
                longitude DOUBLE PRECISION NOT NULL,
                location GEOGRAPHY(POINT) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography) STORED,
                outlet_type TEXT NOT NULL,
                open_days JSONB,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_stores_alko_location ON stores_alko USING GIST(location);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_stores_alko_city ON stores_alko(city);",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE products_alko (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                product_external_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                taste TEXT,
                additional_info TEXT,
                abv DOUBLE PRECISION,
                beer_style_id TEXT[],
                beer_style_name TEXT[],
                beer_substyle_id TEXT[],
                country_name TEXT,
                food_symbol_id TEXT[],
                main_group_id TEXT[],
                price DOUBLE PRECISION,
                product_group_id TEXT[],
                product_group_name TEXT[],
                volume DOUBLE PRECISION,
                online_availability_datetime_ts BIGINT,
                description TEXT,
                certificate_id TEXT[],
                unavailable_since TIMESTAMP WITH TIME ZONE,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_alko_name ON products_alko(name);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_alko_abv ON products_alko(abv);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_alko_country ON products_alko(country_name);",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE products_untappd (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                product_external_id INTEGER NOT NULL UNIQUE,
                name TEXT NOT NULL, 
                label_url TEXT NOT NULL,
                label_hd_url TEXT NOT NULL,
                abv DECIMAL NOT NULL,
                ibu INTEGER NOT NULL,
                description TEXT NOT NULL,
                style TEXT NOT NULL,
                is_in_production INTEGER NOT NULL,
                slug TEXT NOT NULL,
                is_homebrew INTEGER NOT NULL,
                external_created_at TEXT NOT NULL,
                rating_count INTEGER NOT NULL,
                rating_score DECIMAL NOT NULL,
                stats_total_count INTEGER NOT NULL,
                stats_monthly_count INTEGER NOT NULL,
                stats_total_user_count INTEGER NOT NULL,
                stats_user_count INTEGER NOT NULL,
                brewery_id INTEGER NOT NULL,
                brewery_name TEXT NOT NULL,
                brewery_slug TEXT NOT NULL,
                brewery_type TEXT NOT NULL,
                brewery_page_url TEXT NOT NULL,
                brewery_label TEXT NOT NULL,
                brewery_country TEXT NOT NULL,
                brewery_city TEXT NOT NULL,
                brewery_state TEXT NOT NULL,
                brewery_lat DECIMAL NOT NULL,
                brewery_lng DECIMAL NOT NULL,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_untappd_external_id ON products_untappd(product_external_id);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_untappd_name ON products_untappd(name);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_untappd_style ON products_untappd(style);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_products_untappd_rating ON products_untappd(rating_score);",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE availability_alko_webstore (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                product_id UUID NOT NULL REFERENCES products_alko(id),
                status_code TEXT NOT NULL,
                message_code TEXT NOT NULL,
                estimated_availability_date TEXT,
                delivery_min INTEGER,
                delivery_max INTEGER,
                status_en TEXT NOT NULL,
                status_fi TEXT NOT NULL,
                status_sv TEXT NOT NULL,
                status_message TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(product_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_availability_alko_webstore_product ON availability_alko_webstore(product_id);",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE availability_alko_store (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                store_id UUID NOT NULL REFERENCES stores_alko(id),
                product_id UUID NOT NULL REFERENCES products_alko(id),
                product_count TEXT,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(store_id, product_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_availability_alko_store_product ON availability_alko_store(product_id);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_availability_alko_store_store ON availability_alko_store(store_id);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_availability_alko_store_compound ON availability_alko_store(store_id, product_id);",
            logger: logger,
        )

        try await connection.query(
            """
            CREATE TABLE products_alko_untappd_mapping (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                alko_product_id UUID NOT NULL REFERENCES products_alko(id),
                untappd_product_id UUID NOT NULL REFERENCES products_untappd(id),
                confidence_score INTEGER NOT NULL DEFAULT 0,
                is_verified BOOLEAN DEFAULT FALSE,
                reasoning TEXT NOT NULL DEFAULT 'no reasoning provided',
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(alko_product_id, untappd_product_id)
            );
            """,
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_mapping_alko_product ON products_alko_untappd_mapping(alko_product_id);",
            logger: logger,
        )

        try await connection.query(
            "CREATE INDEX idx_mapping_untappd_product ON products_alko_untappd_mapping(untappd_product_id);",
            logger: logger,
        )
    }

    func revert(connection: PostgresConnection, logger: Logger) async throws {
        // Drop tables in reverse order (respecting foreign key constraints)
        try await connection.query(
            "DROP TABLE IF EXISTS products_alko_untappd_mapping;",
            logger: logger,
        )

        try await connection.query(
            "DROP TABLE IF EXISTS availability_alko_store;",
            logger: logger,
        )

        try await connection.query(
            "DROP TABLE IF EXISTS availability_alko_webstore;",
            logger: logger,
        )

        try await connection.query(
            "DROP TABLE IF EXISTS products_untappd;",
            logger: logger,
        )

        try await connection.query(
            "DROP TABLE IF EXISTS products_alko;",
            logger: logger,
        )

        try await connection.query(
            "DROP TABLE IF EXISTS stores_alko;",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.drop_queue('alko_dlq');",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.drop_queue('alko');",
            logger: logger,
        )

        try await connection.query(
            "SELECT pgmq.drop_queue('untappd');",
            logger: logger,
        )

        try await connection.query(
            "DROP EXTENSION IF EXISTS \"postgis\";",
            logger: logger,
        )

        try await connection.query(
            "DROP EXTENSION IF EXISTS \"uuid-ossp\";",
            logger: logger,
        )
    }
}
