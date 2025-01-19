create schema if not exists "pgmq";

create extension if not exists "pgmq" with schema "pgmq" version '1.4.4';

create sequence "pgmq"."q_beer_populate_alko_availability_dlq_msg_id_seq";

create sequence "pgmq"."q_beer_populate_alko_availability_msg_id_seq";

create sequence "pgmq"."q_beer_populate_untappd_dlq_msg_id_seq";

create sequence "pgmq"."q_beer_populate_untappd_msg_id_seq";

create table "pgmq"."a_beer_populate_alko_availability" (
    "msg_id" bigint not null,
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "archived_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


create table "pgmq"."a_beer_populate_alko_availability_dlq" (
    "msg_id" bigint not null,
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "archived_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


create table "pgmq"."a_beer_populate_untappd" (
    "msg_id" bigint not null,
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "archived_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


create table "pgmq"."a_beer_populate_untappd_dlq" (
    "msg_id" bigint not null,
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "archived_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


create table "pgmq"."q_beer_populate_alko_availability" (
    "msg_id" bigint not null default nextval('pgmq.q_beer_populate_alko_availability_msg_id_seq'::regclass),
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


alter table "pgmq"."q_beer_populate_alko_availability" enable row level security;

create table "pgmq"."q_beer_populate_alko_availability_dlq" (
    "msg_id" bigint not null default nextval('pgmq.q_beer_populate_alko_availability_dlq_msg_id_seq'::regclass),
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


alter table "pgmq"."q_beer_populate_alko_availability_dlq" enable row level security;

create table "pgmq"."q_beer_populate_untappd" (
    "msg_id" bigint not null default nextval('pgmq.q_beer_populate_untappd_msg_id_seq'::regclass),
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


alter table "pgmq"."q_beer_populate_untappd" enable row level security;

create table "pgmq"."q_beer_populate_untappd_dlq" (
    "msg_id" bigint not null default nextval('pgmq.q_beer_populate_untappd_dlq_msg_id_seq'::regclass),
    "read_ct" integer not null default 0,
    "enqueued_at" timestamp with time zone not null default now(),
    "vt" timestamp with time zone not null,
    "message" jsonb
);


alter table "pgmq"."q_beer_populate_untappd_dlq" enable row level security;

CREATE UNIQUE INDEX a_beer_populate_alko_availability_dlq_pkey ON pgmq.a_beer_populate_alko_availability_dlq USING btree (msg_id);

CREATE UNIQUE INDEX a_beer_populate_alko_availability_pkey ON pgmq.a_beer_populate_alko_availability USING btree (msg_id);

CREATE UNIQUE INDEX a_beer_populate_untappd_dlq_pkey ON pgmq.a_beer_populate_untappd_dlq USING btree (msg_id);

CREATE UNIQUE INDEX a_beer_populate_untappd_pkey ON pgmq.a_beer_populate_untappd USING btree (msg_id);

CREATE INDEX archived_at_idx_beer_populate_alko_availability ON pgmq.a_beer_populate_alko_availability USING btree (archived_at);

CREATE INDEX archived_at_idx_beer_populate_alko_availability_dlq ON pgmq.a_beer_populate_alko_availability_dlq USING btree (archived_at);

CREATE INDEX archived_at_idx_beer_populate_untappd ON pgmq.a_beer_populate_untappd USING btree (archived_at);

CREATE INDEX archived_at_idx_beer_populate_untappd_dlq ON pgmq.a_beer_populate_untappd_dlq USING btree (archived_at);

CREATE UNIQUE INDEX q_beer_populate_alko_availability_dlq_pkey ON pgmq.q_beer_populate_alko_availability_dlq USING btree (msg_id);

CREATE INDEX q_beer_populate_alko_availability_dlq_vt_idx ON pgmq.q_beer_populate_alko_availability_dlq USING btree (vt);

CREATE UNIQUE INDEX q_beer_populate_alko_availability_pkey ON pgmq.q_beer_populate_alko_availability USING btree (msg_id);

CREATE INDEX q_beer_populate_alko_availability_vt_idx ON pgmq.q_beer_populate_alko_availability USING btree (vt);

CREATE UNIQUE INDEX q_beer_populate_untappd_dlq_pkey ON pgmq.q_beer_populate_untappd_dlq USING btree (msg_id);

CREATE INDEX q_beer_populate_untappd_dlq_vt_idx ON pgmq.q_beer_populate_untappd_dlq USING btree (vt);

CREATE UNIQUE INDEX q_beer_populate_untappd_pkey ON pgmq.q_beer_populate_untappd USING btree (msg_id);

CREATE INDEX q_beer_populate_untappd_vt_idx ON pgmq.q_beer_populate_untappd USING btree (vt);

alter table "pgmq"."a_beer_populate_alko_availability" add constraint "a_beer_populate_alko_availability_pkey" PRIMARY KEY using index "a_beer_populate_alko_availability_pkey";

alter table "pgmq"."a_beer_populate_alko_availability_dlq" add constraint "a_beer_populate_alko_availability_dlq_pkey" PRIMARY KEY using index "a_beer_populate_alko_availability_dlq_pkey";

alter table "pgmq"."a_beer_populate_untappd" add constraint "a_beer_populate_untappd_pkey" PRIMARY KEY using index "a_beer_populate_untappd_pkey";

alter table "pgmq"."a_beer_populate_untappd_dlq" add constraint "a_beer_populate_untappd_dlq_pkey" PRIMARY KEY using index "a_beer_populate_untappd_dlq_pkey";

alter table "pgmq"."q_beer_populate_alko_availability" add constraint "q_beer_populate_alko_availability_pkey" PRIMARY KEY using index "q_beer_populate_alko_availability_pkey";

alter table "pgmq"."q_beer_populate_alko_availability_dlq" add constraint "q_beer_populate_alko_availability_dlq_pkey" PRIMARY KEY using index "q_beer_populate_alko_availability_dlq_pkey";

alter table "pgmq"."q_beer_populate_untappd" add constraint "q_beer_populate_untappd_pkey" PRIMARY KEY using index "q_beer_populate_untappd_pkey";

alter table "pgmq"."q_beer_populate_untappd_dlq" add constraint "q_beer_populate_untappd_dlq_pkey" PRIMARY KEY using index "q_beer_populate_untappd_dlq_pkey";

create type "pgmq"."message_record" as ("msg_id" bigint, "read_ct" integer, "enqueued_at" timestamp with time zone, "vt" timestamp with time zone, "message" jsonb);

create type "pgmq"."metrics_result" as ("queue_name" text, "queue_length" bigint, "newest_msg_age_sec" integer, "oldest_msg_age_sec" integer, "total_messages" bigint, "scrape_time" timestamp with time zone);

create type "pgmq"."queue_record" as ("queue_name" character varying, "is_partitioned" boolean, "is_unlogged" boolean, "created_at" timestamp with time zone);

grant select on table "pgmq"."a_beer_populate_alko_availability" to "pg_monitor";

grant select on table "pgmq"."a_beer_populate_alko_availability_dlq" to "pg_monitor";

grant select on table "pgmq"."a_beer_populate_untappd" to "pg_monitor";

grant select on table "pgmq"."a_beer_populate_untappd_dlq" to "pg_monitor";

grant select on table "pgmq"."meta" to "pg_monitor";

grant select on table "pgmq"."q_beer_populate_alko_availability" to "pg_monitor";

grant select on table "pgmq"."q_beer_populate_alko_availability_dlq" to "pg_monitor";

grant select on table "pgmq"."q_beer_populate_untappd" to "pg_monitor";

grant select on table "pgmq"."q_beer_populate_untappd_dlq" to "pg_monitor";


drop trigger if exists "enqueue_new_beer" on "public"."beer_alko";

create table "public"."alko_store" (
    "oid" text not null,
    "name" text not null,
    "address" text not null,
    "city" text not null,
    "postal_code" text not null,
    "latitude" numeric(10,8) not null,
    "longitude" numeric(11,8) not null,
    "outlet_type" text not null,
    "id" uuid not null default gen_random_uuid(),
    "mapkit_id" text
);


create table "public"."beer_untappd_metadata" (
    "beer_id" uuid not null,
    "bid" integer,
    "beer_name" text,
    "beer_label" text,
    "beer_abv" numeric(4,1),
    "beer_ibu" integer,
    "beer_description" text,
    "beer_style" text,
    "beer_created_at" timestamp without time zone,
    "in_production" boolean,
    "auth_rating" numeric(3,2),
    "wish_list" boolean,
    "checkin_count" integer default 0,
    "have_had" boolean default false,
    "your_count" integer default 0,
    "brewery_id" integer,
    "brewery_name" text,
    "brewery_label" text,
    "brewery_type" character varying(50),
    "brewery_active" boolean,
    "brewery_city" text,
    "brewery_state" text,
    "country_name" text,
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "brewery_website" text,
    "brewery_twitter" text,
    "brewery_facebook" text,
    "brewery_instagram" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "rating_count" integer,
    "rating_score" numeric,
    "has_had" boolean
);


create table "public"."store_inventory" (
    "store_id" uuid not null,
    "beer_id" uuid not null,
    "product_count" text
);


create table "public"."webstore_invetory" (
    "beer_id" uuid not null,
    "status_code" text not null,
    "message_code" text not null,
    "estimated_availability_date" date,
    "delivery_min" integer,
    "delivery_max" integer,
    "status_en" text not null,
    "status_fi" text not null,
    "status_sv" text not null,
    "status_message" text not null,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."beer_alko" add column "alko_image_url" text generated always as (('https://images.alko.fi/t_medium,f_auto/cdn/'::text || product_code)) stored;

alter table "public"."beer_alko" add column "beer_style_en" text generated always as (
CASE
    WHEN (lower(beer_style) = 'vehnäolut'::text) THEN 'Wheat Beer'::text
    WHEN (lower(beer_style) = 'vahva lager'::text) THEN 'Strong Lager'::text
    WHEN (lower(beer_style) = 'tumma lager'::text) THEN 'Dark Lager'::text
    WHEN (lower(beer_style) = 'stout & porter'::text) THEN 'Stout & Porter'::text
    WHEN (lower(beer_style) = 'pils'::text) THEN 'Pilsner'::text
    WHEN (lower(beer_style) = 'lager'::text) THEN 'Lager'::text
    WHEN (lower(beer_style) = 'ipa'::text) THEN 'IPA'::text
    WHEN (lower(beer_style) = 'erikoisuus'::text) THEN 'Specialty Beer'::text
    WHEN (lower(beer_style) = 'ale'::text) THEN 'Ale'::text
    ELSE beer_style
END) stored;

alter table "public"."beer_alko" add column "image_url" text;

alter table "public"."beer_alko" add column "name_clean" text generated always as (TRIM(BOTH FROM regexp_replace(regexp_replace(name, ' tölkki$'::text, ''::text, 'i'::text), '  +'::text, ' '::text, 'g'::text))) stored;

alter table "public"."beer_alko" add column "package_type_en" text generated always as (
CASE
    WHEN (lower(package_type) = 'hanapakkaus'::text) THEN 'tap box'::text
    WHEN (lower(package_type) = 'tölkki'::text) THEN 'can'::text
    WHEN (lower(package_type) = 'pullo'::text) THEN 'bottle'::text
    ELSE package_type
END) stored;

alter table "public"."beer_untappd" add column "has_had" boolean;

alter table "public"."beer_untappd" add column "rating_count" integer;

alter table "public"."beer_untappd" add column "rating_score" numeric;

CREATE UNIQUE INDEX alko_store_pkey ON public.alko_store USING btree (id);

CREATE UNIQUE INDEX alko_store_store_oid_key ON public.alko_store USING btree (oid);

CREATE UNIQUE INDEX beer_untappd_metadata_pkey ON public.beer_untappd_metadata USING btree (beer_id);

CREATE UNIQUE INDEX store_inventory_pkey ON public.store_inventory USING btree (store_id, beer_id);

CREATE UNIQUE INDEX webstore_invetory_pkey ON public.webstore_invetory USING btree (beer_id);

alter table "public"."alko_store" add constraint "alko_store_pkey" PRIMARY KEY using index "alko_store_pkey";

alter table "public"."beer_untappd_metadata" add constraint "beer_untappd_metadata_pkey" PRIMARY KEY using index "beer_untappd_metadata_pkey";

alter table "public"."store_inventory" add constraint "store_inventory_pkey" PRIMARY KEY using index "store_inventory_pkey";

alter table "public"."webstore_invetory" add constraint "webstore_invetory_pkey" PRIMARY KEY using index "webstore_invetory_pkey";

alter table "public"."alko_store" add constraint "alko_store_store_oid_key" UNIQUE using index "alko_store_store_oid_key";

alter table "public"."beer_untappd_metadata" add constraint "beer_untappd_metadata_beer_id_fk" FOREIGN KEY (beer_id) REFERENCES beer_alko(id) ON DELETE CASCADE not valid;

alter table "public"."beer_untappd_metadata" validate constraint "beer_untappd_metadata_beer_id_fk";

alter table "public"."store_inventory" add constraint "store_inventory_beer_id_fkey" FOREIGN KEY (beer_id) REFERENCES beer_alko(id) ON DELETE CASCADE not valid;

alter table "public"."store_inventory" validate constraint "store_inventory_beer_id_fkey";

alter table "public"."store_inventory" add constraint "store_inventory_store_id_fkey" FOREIGN KEY (store_id) REFERENCES alko_store(id) ON DELETE CASCADE not valid;

alter table "public"."store_inventory" validate constraint "store_inventory_store_id_fkey";

alter table "public"."webstore_invetory" add constraint "webstore_invetory_beer_id_fkey" FOREIGN KEY (beer_id) REFERENCES beer_alko(id) not valid;

alter table "public"."webstore_invetory" validate constraint "webstore_invetory_beer_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.fnc__enqueue_alko_availability_refresh()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    message_count INTEGER := 0;
BEGIN
    WITH beer_messages AS (
        SELECT ARRAY_AGG(
            jsonb_build_object(
                'beer_id', id
            )
        ) as msgs
        FROM beer_alko
    )
    SELECT COUNT(*)
    INTO message_count
    FROM beer_messages,
         LATERAL pgmq.send_batch('beer_populate_alko_availability', msgs)
    WHERE msgs IS NOT NULL;

    RETURN message_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fnc__get_beer_store_data()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    result jsonb;
BEGIN
    WITH beer_data AS (
        SELECT
            ba.id,
            ba.name,
            ba.manufacturer,
            ba.price,
            ba.alcohol_percentage,
            ba.product_code,
            ba.package_type,
            ba.beer_style as alko_beer_style,
            ba.container_size,
            ba.type as alko_type,
            bu.bid,
            bu.beer_style as untappd_beer_style,
            bu.rating_score,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'store_id', si.store_id,
                        'count', si.product_count
                    )
                ) FILTER (WHERE si.store_id IS NOT NULL),
                '[]'::jsonb
            ) as availability
        FROM beer_alko ba
        LEFT JOIN beer_alko_beer_untappd babu ON ba.id = babu.beer_alko_id
        LEFT JOIN beer_untappd bu ON babu.beer_untappd_id = bu.id
        LEFT JOIN store_inventory si ON ba.id = si.beer_id
        GROUP BY ba.id, ba.name, ba.manufacturer, ba.price,
                 ba.alcohol_percentage, ba.product_code, ba.beer_style, ba.type,
                 bu.bid, bu.beer_style, bu.rating_score
    ),
    store_data AS (
        SELECT
            jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'address', address,
                    'city', city,
                    'postal_code', postal_code,
                    'latitude', latitude,
                    'longitude', longitude,
                    'mapkit_id', mapkit_id
                )
            ) as stores
        FROM alko_store
        WHERE outlet_type = 'myymalat'
    ),
    webstore_data AS (
        SELECT
            jsonb_object_agg(
                wi.beer_id::text,
                jsonb_build_object(
                    'status_code', wi.status_code,
                    'message_code', wi.message_code,
                    'estimated_availability_date', wi.estimated_availability_date,
                    'delivery_min', wi.delivery_min,
                    'delivery_max', wi.delivery_max,
                    'status_en', wi.status_en,
                    'status_fi', wi.status_fi,
                    'status_sv', wi.status_sv,
                    'status_message', wi.status_message
                )
            ) as webstore_availability
        FROM webstore_invetory wi
    )
    SELECT
        jsonb_build_object(
            'beers', COALESCE((
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', id,
                        'name', name,
                        'manufacturer', manufacturer,
                        'price', price,
                        'alcohol_percentage', alcohol_percentage,
                        'product_code', product_code,
                        'alko_beer_style', alko_beer_style,
                        'alko_type', alko_type,
                        'untappd_beer_style', untappd_beer_style,
                        'untappd_bid', bid,
                        'rating', rating_score,
                        'availability', availability,
                        'package_type', package_type,
                        'container_size', container_size
                    )
                ) FROM beer_data
            ), '[]'::jsonb),
            'stores', COALESCE((SELECT stores FROM store_data), '[]'::jsonb),
            'webstore', COALESCE((SELECT webstore_availability FROM webstore_data), '{}'::jsonb)
        ) INTO result;

    RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fnc__get_response()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    result jsonb;
BEGIN
    WITH beer_data AS (
        SELECT
            b.*
        FROM view__beer b
        GROUP BY b.id, b.name, b.manufacturer, b.price, b.alcohol_percentage,
                 b.alko_id, b.package_type, b.container_size, b.beer_style,
                 b.untappd_id, b.rating, b.price_per_liter,
                 b.bitterness_ibu, b.image_url, b.rating_count
    ),
    store_beers AS (
        SELECT
            store_id,
            jsonb_agg(beer_id) as beer_ids
        FROM store_inventory
        GROUP BY store_id
    ),
    store_data AS (
        SELECT
            jsonb_object_agg(
                id,
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'address', address,
                    'city', city,
                    'postal_code', postal_code,
                    'latitude', latitude,
                    'longitude', longitude,
                    'mapkit_id', mapkit_id,
                    'beers', COALESCE((SELECT beer_ids FROM store_beers WHERE store_id = id), '[]'::jsonb)
                )
            ) as stores
        FROM alko_store
        WHERE outlet_type = 'myymalat'
    ),
    beer_map AS (
        SELECT
            jsonb_object_agg(
                id,
                jsonb_build_object(
                    'id', id,
                    'untappd_id', untappd_id,
                    'alko_id', alko_id,
                    'name', name,
                    'manufacturer', manufacturer,
                    'price', price,
                    'alcohol_percentage', alcohol_percentage,
                    'beer_style', beer_style,
                    'rating', rating,
                    'rating_count', rating_count,
                    'package_type', package_type,
                    'container_size', container_size,
                    'price_per_liter', price_per_liter,
                    'bitterness_ibu', bitterness_ibu,
                    'image_url', image_url
                )
            ) as beers
        FROM beer_data
    ),
    webstore_data AS (
        SELECT
            jsonb_object_agg(
                wi.beer_id::text,
                jsonb_build_object(
                    'status_code', wi.status_code,
                    'message_code', wi.message_code,
                    'estimated_availability_date', wi.estimated_availability_date,
                    'delivery_min', wi.delivery_min,
                    'delivery_max', wi.delivery_max,
                    'status', wi.status_en
                )
            ) as webstore_availability
        FROM webstore_invetory wi
    )
    SELECT
        jsonb_build_object(
            'beers', COALESCE((SELECT beers FROM beer_map), '{}'::jsonb),
            'stores', COALESCE((SELECT stores FROM store_data), '{}'::jsonb),
            'webstore', COALESCE((SELECT webstore_availability FROM webstore_data), '{}'::jsonb)
        ) INTO result;

    RETURN result;
END;
$function$
;

create materialized view "public"."materialized_view_response" as  SELECT fnc__get_response() AS data;


create or replace view "public"."view__beer" as  SELECT ba.id,
    ba.product_code AS alko_id,
    bum.bid AS untappd_id,
    ba.name_clean AS name,
    ba.manufacturer,
    ba.price,
    ba.price_per_liter,
    ba.package_type_en AS package_type,
    ba.container_size,
    ba.bitterness_ibu,
    ba.alcohol_percentage,
    ba.image_url,
    COALESCE(bum.beer_style, ba.beer_style_en) AS beer_style,
    bum.rating_score AS rating,
    bum.rating_count
   FROM (beer_alko ba
     LEFT JOIN beer_untappd_metadata bum ON ((ba.id = bum.beer_id)));


CREATE OR REPLACE FUNCTION public.fnc__enqueue_beer_refresh()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    message_count INTEGER := 0;
BEGIN
    WITH beer_messages AS (
        SELECT ARRAY_AGG(
            jsonb_build_object(
                'beer_id', id,
                'manufacturer', manufacturer,
                'name', name
            )
        ) as msgs
        FROM beer_alko
    )
    SELECT COUNT(*)
    INTO message_count
    FROM beer_messages, 
         LATERAL pgmq.send_batch('beer_populate_untappd', msgs)
    WHERE msgs IS NOT NULL;

    RETURN message_count;
END;
$function$
;

grant delete on table "public"."alko_store" to "anon";

grant insert on table "public"."alko_store" to "anon";

grant references on table "public"."alko_store" to "anon";

grant select on table "public"."alko_store" to "anon";

grant trigger on table "public"."alko_store" to "anon";

grant truncate on table "public"."alko_store" to "anon";

grant update on table "public"."alko_store" to "anon";

grant delete on table "public"."alko_store" to "authenticated";

grant insert on table "public"."alko_store" to "authenticated";

grant references on table "public"."alko_store" to "authenticated";

grant select on table "public"."alko_store" to "authenticated";

grant trigger on table "public"."alko_store" to "authenticated";

grant truncate on table "public"."alko_store" to "authenticated";

grant update on table "public"."alko_store" to "authenticated";

grant delete on table "public"."alko_store" to "service_role";

grant insert on table "public"."alko_store" to "service_role";

grant references on table "public"."alko_store" to "service_role";

grant select on table "public"."alko_store" to "service_role";

grant trigger on table "public"."alko_store" to "service_role";

grant truncate on table "public"."alko_store" to "service_role";

grant update on table "public"."alko_store" to "service_role";

grant delete on table "public"."beer_untappd_metadata" to "anon";

grant insert on table "public"."beer_untappd_metadata" to "anon";

grant references on table "public"."beer_untappd_metadata" to "anon";

grant select on table "public"."beer_untappd_metadata" to "anon";

grant trigger on table "public"."beer_untappd_metadata" to "anon";

grant truncate on table "public"."beer_untappd_metadata" to "anon";

grant update on table "public"."beer_untappd_metadata" to "anon";

grant delete on table "public"."beer_untappd_metadata" to "authenticated";

grant insert on table "public"."beer_untappd_metadata" to "authenticated";

grant references on table "public"."beer_untappd_metadata" to "authenticated";

grant select on table "public"."beer_untappd_metadata" to "authenticated";

grant trigger on table "public"."beer_untappd_metadata" to "authenticated";

grant truncate on table "public"."beer_untappd_metadata" to "authenticated";

grant update on table "public"."beer_untappd_metadata" to "authenticated";

grant delete on table "public"."beer_untappd_metadata" to "service_role";

grant insert on table "public"."beer_untappd_metadata" to "service_role";

grant references on table "public"."beer_untappd_metadata" to "service_role";

grant select on table "public"."beer_untappd_metadata" to "service_role";

grant trigger on table "public"."beer_untappd_metadata" to "service_role";

grant truncate on table "public"."beer_untappd_metadata" to "service_role";

grant update on table "public"."beer_untappd_metadata" to "service_role";

grant delete on table "public"."store_inventory" to "anon";

grant insert on table "public"."store_inventory" to "anon";

grant references on table "public"."store_inventory" to "anon";

grant select on table "public"."store_inventory" to "anon";

grant trigger on table "public"."store_inventory" to "anon";

grant truncate on table "public"."store_inventory" to "anon";

grant update on table "public"."store_inventory" to "anon";

grant delete on table "public"."store_inventory" to "authenticated";

grant insert on table "public"."store_inventory" to "authenticated";

grant references on table "public"."store_inventory" to "authenticated";

grant select on table "public"."store_inventory" to "authenticated";

grant trigger on table "public"."store_inventory" to "authenticated";

grant truncate on table "public"."store_inventory" to "authenticated";

grant update on table "public"."store_inventory" to "authenticated";

grant delete on table "public"."store_inventory" to "service_role";

grant insert on table "public"."store_inventory" to "service_role";

grant references on table "public"."store_inventory" to "service_role";

grant select on table "public"."store_inventory" to "service_role";

grant trigger on table "public"."store_inventory" to "service_role";

grant truncate on table "public"."store_inventory" to "service_role";

grant update on table "public"."store_inventory" to "service_role";

grant delete on table "public"."webstore_invetory" to "anon";

grant insert on table "public"."webstore_invetory" to "anon";

grant references on table "public"."webstore_invetory" to "anon";

grant select on table "public"."webstore_invetory" to "anon";

grant trigger on table "public"."webstore_invetory" to "anon";

grant truncate on table "public"."webstore_invetory" to "anon";

grant update on table "public"."webstore_invetory" to "anon";

grant delete on table "public"."webstore_invetory" to "authenticated";

grant insert on table "public"."webstore_invetory" to "authenticated";

grant references on table "public"."webstore_invetory" to "authenticated";

grant select on table "public"."webstore_invetory" to "authenticated";

grant trigger on table "public"."webstore_invetory" to "authenticated";

grant truncate on table "public"."webstore_invetory" to "authenticated";

grant update on table "public"."webstore_invetory" to "authenticated";

grant delete on table "public"."webstore_invetory" to "service_role";

grant insert on table "public"."webstore_invetory" to "service_role";

grant references on table "public"."webstore_invetory" to "service_role";

grant select on table "public"."webstore_invetory" to "service_role";

grant trigger on table "public"."webstore_invetory" to "service_role";

grant truncate on table "public"."webstore_invetory" to "service_role";

grant update on table "public"."webstore_invetory" to "service_role";


