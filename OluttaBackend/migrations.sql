begin;

DO
$body$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_proc WHERE proname = 'apply_migration') THEN
    CREATE FUNCTION apply_migration (migration_name TEXT, ddl TEXT) RETURNS BOOLEAN
      AS $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_tables WHERE tablename = 'applied_migrations') THEN
        CREATE TABLE applied_migrations (
            identifier TEXT NOT NULL PRIMARY KEY
          , ddl TEXT NOT NULL
          , applied_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        );
      END IF;
      LOCK TABLE applied_migrations IN EXCLUSIVE MODE;
      IF NOT EXISTS (SELECT 1 FROM applied_migrations m WHERE m.identifier = migration_name)
      THEN
        RAISE NOTICE 'Applying migration: %', migration_name;
        EXECUTE ddl;
        INSERT INTO applied_migrations (identifier, ddl) VALUES (migration_name, ddl);
        RETURN TRUE;
      END IF;
      RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql;
  END IF;
END
$body$;

SELECT apply_migration('enable_extensions',
$$
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE EXTENSION IF NOT EXISTS "postgis";
$$);

SELECT apply_migration('enable_pgmq',
$$
  SELECT pgmq.create('untappd');
  SELECT pgmq.create('alko_dlq');
  SELECT pgmq.create('alko');
  SELECT pgmq.create('alko_dlq');
$$);

SELECT apply_migration('create_stores_alko_table',
$$
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
  CREATE INDEX idx_stores_alko_location ON stores_alko USING GIST(location);
  CREATE INDEX idx_stores_alko_city ON stores_alko(city);
$$);

SELECT apply_migration('create_products_alko_table',
$$
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
      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
  );  
  CREATE INDEX idx_products_alko_name ON products_alko(name);
  CREATE INDEX idx_products_alko_abv ON products_alko(abv);
  CREATE INDEX idx_products_alko_country ON products_alko(country_name);
$$);

SELECT apply_migration('create_products_untappd_table',
$$
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
  CREATE INDEX idx_products_untappd_external_id ON products_untappd(product_external_id);
  CREATE INDEX idx_products_untappd_name ON products_untappd(name);
  CREATE INDEX idx_products_untappd_style ON products_untappd(style);
  CREATE INDEX idx_products_untappd_rating ON products_untappd(rating_score);
$$);

SELECT apply_migration('create_availability_alko_webstore_table',
$$
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
  CREATE INDEX idx_availability_alko_webstore_product ON availability_alko_webstore(product_id);
$$);

SELECT apply_migration('create_availability_alko_store_table',
$$
  CREATE TABLE availability_alko_store (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      store_id UUID NOT NULL REFERENCES stores_alko(id),
      product_id UUID NOT NULL REFERENCES products_alko(id),
      product_count TEXT,
      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(store_id, product_id)
  );
  CREATE INDEX idx_availability_alko_store_product ON availability_alko_store(product_id);
  CREATE INDEX idx_availability_alko_store_store ON availability_alko_store(store_id);
  CREATE INDEX idx_availability_alko_store_compound ON availability_alko_store(store_id, product_id);
$$);

SELECT apply_migration('create_products_alko_untappd_mapping',
$$
  CREATE TABLE products_alko_untappd_mapping (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      alko_product_id UUID NOT NULL REFERENCES products_alko(id),
      untappd_product_id UUID NOT NULL REFERENCES products_untappd(id),
      confidence_score DECIMAL,
      is_verified BOOLEAN DEFAULT FALSE,
      notes TEXT,
      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(alko_product_id, untappd_product_id)
  );  
  CREATE INDEX idx_mapping_alko_product ON products_alko_untappd_mapping(alko_product_id);
  CREATE INDEX idx_mapping_untappd_product ON products_alko_untappd_mapping(untappd_product_id);
$$);

SELECT apply_migration('alter_confidence_score_to_not_null_int',
$$
  UPDATE products_alko_untappd_mapping
  SET confidence_score = 0
  WHERE confidence_score IS NULL;
  ALTER TABLE products_alko_untappd_mapping
  ALTER COLUMN confidence_score TYPE INTEGER USING (confidence_score::INTEGER),
  ALTER COLUMN confidence_score SET NOT NULL;
$$);

SELECT apply_migration('add_reasoning_to_mapping',
$$
  ALTER TABLE products_alko_untappd_mapping
  ADD COLUMN reasoning TEXT;
  UPDATE products_alko_untappd_mapping
  SET reasoning = 'no reasoning provided'
  WHERE reasoning IS NULL;
  ALTER TABLE products_alko_untappd_mapping
  ALTER COLUMN reasoning SET NOT NULL;  
  ALTER TABLE products_alko_untappd_mapping
  DROP COLUMN IF EXISTS notes;
$$);

commit;
