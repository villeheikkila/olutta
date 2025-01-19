create table "public"."beer_alko" (
    "id" uuid not null default gen_random_uuid(),
    "product_code" text not null,
    "name" text not null,
    "manufacturer" text not null,
    "container_size" text not null,
    "price" numeric(10,2) not null,
    "price_per_liter" numeric(10,2),
    "type" text not null,
    "beer_style" text,
    "country" text,
    "alcohol_percentage" numeric(4,2) not null,
    "original_gravity" numeric(5,2),
    "color_ebc" numeric(5,1),
    "bitterness_ibu" numeric(5,1),
    "package_type" text,
    "energy_kcal" integer,
    "ean" text,
    "created_at" timestamp with time zone default CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone default CURRENT_TIMESTAMP,
    "alko_url" text generated always as (('https://www.alko.fi/tuotteet/'::text || product_code)) stored
);


create table "public"."beer_alko_beer_untappd" (
    "beer_alko_id" uuid not null,
    "beer_untappd_id" uuid not null,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


create table "public"."beer_untappd" (
    "bid" integer not null,
    "beer_name" character varying(255) not null,
    "beer_label" text,
    "beer_abv" numeric(4,1),
    "beer_ibu" integer,
    "beer_description" text,
    "beer_style" character varying(255),
    "beer_created_at" timestamp without time zone,
    "in_production" boolean,
    "auth_rating" numeric(3,2),
    "wish_list" boolean,
    "checkin_count" integer default 0,
    "have_had" boolean default false,
    "your_count" integer default 0,
    "brewery_id" integer,
    "brewery_name" character varying(255),
    "brewery_label" text,
    "brewery_type" character varying(50),
    "brewery_active" boolean,
    "brewery_city" character varying(255),
    "brewery_state" character varying(255),
    "country_name" character varying(255),
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "brewery_website" text,
    "brewery_twitter" character varying(255),
    "brewery_facebook" character varying(255),
    "brewery_instagram" character varying(255),
    "created_at" timestamp without time zone default CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone default CURRENT_TIMESTAMP,
    "untappd_url" text generated always as (('https://untappd.com/qr/beer/'::text || bid)) stored,
    "id" uuid not null default gen_random_uuid()
);


CREATE UNIQUE INDEX beer_alko_beer_untappd_pkey ON public.beer_alko_beer_untappd USING btree (beer_alko_id, beer_untappd_id);

CREATE UNIQUE INDEX beers_pkey ON public.beer_alko USING btree (id);

CREATE UNIQUE INDEX beers_product_code_key ON public.beer_alko USING btree (product_code);

CREATE INDEX idx_beer_alko_beer_untappd_untappd_id ON public.beer_alko_beer_untappd USING btree (beer_untappd_id);

CREATE UNIQUE INDEX untappd_beer_bid_unique ON public.beer_untappd USING btree (bid);

CREATE UNIQUE INDEX untappd_beer_pkey ON public.beer_untappd USING btree (id);

alter table "public"."beer_alko" add constraint "beers_pkey" PRIMARY KEY using index "beers_pkey";

alter table "public"."beer_alko_beer_untappd" add constraint "beer_alko_beer_untappd_pkey" PRIMARY KEY using index "beer_alko_beer_untappd_pkey";

alter table "public"."beer_untappd" add constraint "untappd_beer_pkey" PRIMARY KEY using index "untappd_beer_pkey";

alter table "public"."beer_alko" add constraint "beers_product_code_key" UNIQUE using index "beers_product_code_key";

alter table "public"."beer_alko_beer_untappd" add constraint "beer_alko_beer_untappd_beer_alko_id_fkey" FOREIGN KEY (beer_alko_id) REFERENCES beer_alko(id) not valid;

alter table "public"."beer_alko_beer_untappd" validate constraint "beer_alko_beer_untappd_beer_alko_id_fkey";

alter table "public"."beer_alko_beer_untappd" add constraint "beer_alko_beer_untappd_beer_untappd_id_fkey" FOREIGN KEY (beer_untappd_id) REFERENCES beer_untappd(id) not valid;

alter table "public"."beer_alko_beer_untappd" validate constraint "beer_alko_beer_untappd_beer_untappd_id_fkey";

alter table "public"."beer_untappd" add constraint "untappd_beer_bid_unique" UNIQUE using index "untappd_beer_bid_unique";

set check_function_bodies = off;

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
        FROM beers
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

CREATE OR REPLACE FUNCTION public.tg__enqueue_new_beer()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM pgmq.send(
        'beer_populate_untappd',
        jsonb_build_object(
            'beer_id', NEW.id,
            'manufacturer', NEW.manufacturer,
            'name', NEW.name
        )::text
    );
    
    RETURN NEW;
END;
$function$
;

grant delete on table "public"."beer_alko" to "anon";

grant insert on table "public"."beer_alko" to "anon";

grant references on table "public"."beer_alko" to "anon";

grant select on table "public"."beer_alko" to "anon";

grant trigger on table "public"."beer_alko" to "anon";

grant truncate on table "public"."beer_alko" to "anon";

grant update on table "public"."beer_alko" to "anon";

grant delete on table "public"."beer_alko" to "authenticated";

grant insert on table "public"."beer_alko" to "authenticated";

grant references on table "public"."beer_alko" to "authenticated";

grant select on table "public"."beer_alko" to "authenticated";

grant trigger on table "public"."beer_alko" to "authenticated";

grant truncate on table "public"."beer_alko" to "authenticated";

grant update on table "public"."beer_alko" to "authenticated";

grant delete on table "public"."beer_alko" to "service_role";

grant insert on table "public"."beer_alko" to "service_role";

grant references on table "public"."beer_alko" to "service_role";

grant select on table "public"."beer_alko" to "service_role";

grant trigger on table "public"."beer_alko" to "service_role";

grant truncate on table "public"."beer_alko" to "service_role";

grant update on table "public"."beer_alko" to "service_role";

grant delete on table "public"."beer_alko_beer_untappd" to "anon";

grant insert on table "public"."beer_alko_beer_untappd" to "anon";

grant references on table "public"."beer_alko_beer_untappd" to "anon";

grant select on table "public"."beer_alko_beer_untappd" to "anon";

grant trigger on table "public"."beer_alko_beer_untappd" to "anon";

grant truncate on table "public"."beer_alko_beer_untappd" to "anon";

grant update on table "public"."beer_alko_beer_untappd" to "anon";

grant delete on table "public"."beer_alko_beer_untappd" to "authenticated";

grant insert on table "public"."beer_alko_beer_untappd" to "authenticated";

grant references on table "public"."beer_alko_beer_untappd" to "authenticated";

grant select on table "public"."beer_alko_beer_untappd" to "authenticated";

grant trigger on table "public"."beer_alko_beer_untappd" to "authenticated";

grant truncate on table "public"."beer_alko_beer_untappd" to "authenticated";

grant update on table "public"."beer_alko_beer_untappd" to "authenticated";

grant delete on table "public"."beer_alko_beer_untappd" to "service_role";

grant insert on table "public"."beer_alko_beer_untappd" to "service_role";

grant references on table "public"."beer_alko_beer_untappd" to "service_role";

grant select on table "public"."beer_alko_beer_untappd" to "service_role";

grant trigger on table "public"."beer_alko_beer_untappd" to "service_role";

grant truncate on table "public"."beer_alko_beer_untappd" to "service_role";

grant update on table "public"."beer_alko_beer_untappd" to "service_role";

grant delete on table "public"."beer_untappd" to "anon";

grant insert on table "public"."beer_untappd" to "anon";

grant references on table "public"."beer_untappd" to "anon";

grant select on table "public"."beer_untappd" to "anon";

grant trigger on table "public"."beer_untappd" to "anon";

grant truncate on table "public"."beer_untappd" to "anon";

grant update on table "public"."beer_untappd" to "anon";

grant delete on table "public"."beer_untappd" to "authenticated";

grant insert on table "public"."beer_untappd" to "authenticated";

grant references on table "public"."beer_untappd" to "authenticated";

grant select on table "public"."beer_untappd" to "authenticated";

grant trigger on table "public"."beer_untappd" to "authenticated";

grant truncate on table "public"."beer_untappd" to "authenticated";

grant update on table "public"."beer_untappd" to "authenticated";

grant delete on table "public"."beer_untappd" to "service_role";

grant insert on table "public"."beer_untappd" to "service_role";

grant references on table "public"."beer_untappd" to "service_role";

grant select on table "public"."beer_untappd" to "service_role";

grant trigger on table "public"."beer_untappd" to "service_role";

grant truncate on table "public"."beer_untappd" to "service_role";

grant update on table "public"."beer_untappd" to "service_role";

CREATE TRIGGER enqueue_new_beer AFTER INSERT ON public.beer_alko FOR EACH ROW EXECUTE FUNCTION tg__enqueue_new_beer();


