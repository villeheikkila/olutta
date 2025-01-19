import { Context } from "../context.ts";
import * as untappd from "../untappd/index.ts";

const query = `
INSERT INTO beer_untappd (
  bid,
  beer_name,
  beer_label,
  beer_abv,
  beer_ibu,
  beer_description,
  beer_style,
  beer_created_at,
  in_production,
  auth_rating,
  wish_list,
  checkin_count,
  have_had,
  your_count,
  brewery_id,
  brewery_name,
  brewery_label,
  brewery_type,
  brewery_active,
  brewery_city,
  brewery_state,
  country_name,
  latitude,
  longitude,
  brewery_website,
  brewery_twitter,
  brewery_facebook,
  brewery_instagram,
  rating_score,
  rating_count
) VALUES (
  $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
  $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
  $21, $22, $23, $24, $25, $26, $27, $28, $29, $30
)
ON CONFLICT (bid) DO UPDATE SET
  beer_name = EXCLUDED.beer_name,
  beer_label = EXCLUDED.beer_label,
  beer_abv = EXCLUDED.beer_abv,
  beer_ibu = EXCLUDED.beer_ibu,
  beer_description = EXCLUDED.beer_description,
  beer_style = EXCLUDED.beer_style,
  beer_created_at = EXCLUDED.beer_created_at,
  in_production = EXCLUDED.in_production,
  auth_rating = EXCLUDED.auth_rating,
  wish_list = EXCLUDED.wish_list,
  checkin_count = EXCLUDED.checkin_count,
  have_had = EXCLUDED.have_had,
  your_count = EXCLUDED.your_count,
  brewery_id = EXCLUDED.brewery_id,
  brewery_name = EXCLUDED.brewery_name,
  brewery_label = EXCLUDED.brewery_label,
  brewery_type = EXCLUDED.brewery_type,
  brewery_active = EXCLUDED.brewery_active,
  brewery_city = EXCLUDED.brewery_city,
  brewery_state = EXCLUDED.brewery_state,
  country_name = EXCLUDED.country_name,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  brewery_website = EXCLUDED.brewery_website,
  brewery_twitter = EXCLUDED.brewery_twitter,
  brewery_facebook = EXCLUDED.brewery_facebook,
  brewery_instagram = EXCLUDED.brewery_instagram,
  updated_at = CURRENT_TIMESTAMP,
  rating_score = EXCLUDED.rating_score,
  rating_count = EXCLUDED.rating_count
RETURNING id`;

const storeUntappdBeer = async (
  ctx: Context,
  beerData: untappd.UntappdBeer,
  metadata: untappd.BeerMetadata
): Promise<{ id: number } | null> => {
  const values = [
    beerData.beer.bid,
    beerData.beer.beer_name,
    beerData.beer.beer_label,
    beerData.beer.beer_abv,
    beerData.beer.beer_ibu,
    beerData.beer.beer_description,
    beerData.beer.beer_style,
    beerData.beer.created_at,
    beerData.beer.in_production,
    beerData.beer.auth_rating,
    beerData.beer.wish_list,
    beerData.checkin_count,
    beerData.have_had,
    beerData.your_count,
    beerData.brewery.brewery_id,
    beerData.brewery.brewery_name,
    beerData.brewery.brewery_label,
    beerData.brewery.brewery_type,
    beerData.brewery.brewery_active,
    beerData.brewery.location.brewery_city,
    beerData.brewery.location.brewery_state,
    beerData.brewery.country_name,
    beerData.brewery.location.lat,
    beerData.brewery.location.lng,
    beerData.brewery.contact.url,
    beerData.brewery.contact.twitter,
    beerData.brewery.contact.facebook,
    beerData.brewery.contact.instagram,
    metadata.rating_score,
    metadata.rating_count,
  ];
  const result = await ctx.pg.queryObject<{ id: number }>(query, values);
  return result.rows[0] ?? null;
};

export { storeUntappdBeer };
