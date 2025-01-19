import { z } from "https://deno.land/x/zod@v3.24.1/mod.ts";
import { Context } from "../context.ts";

async function searchBeer(
  ctx: Context,
  name: string
): Promise<UntappdBeer | null> {
  console.log("searching for beer:", name);
  try {
    const response = await fetch(
      `https://api.untappd.com/v4/search/beer?q=${name}&client_id=${ctx.cfg.untappd.clientId}&client_secret=${ctx.cfg.untappd.clientSecret}`
    );
    console.log("response ", response);
    if (!response.ok) {
      console.error("error loading response:", response);
      return null;
    }
    const rawData = await response.json();
    const parsedData = UntappdSearchResponse.safeParse(rawData);
    if (!parsedData.success) {
      console.error("error parsing Untappd response:", parsedData.error);
      return null;
    }
    return parsedData.data.response.beers.items[0];
  } catch (err) {
    console.error("error loading response:", err);
    return null;
  }
}

const UntappdBeer = z.object({
  checkin_count: z.number(),
  have_had: z.boolean(),
  your_count: z.number(),
  beer: z.object({
    bid: z.number(),
    beer_name: z.string(),
    beer_label: z.string(),
    beer_abv: z.number(),
    beer_slug: z.string(),
    beer_ibu: z.number(),
    beer_description: z.string(),
    created_at: z.string(),
    beer_style: z.string(),
    in_production: z.number(),
    auth_rating: z.number(),
    wish_list: z.boolean(),
  }),
  brewery: z.object({
    brewery_id: z.number(),
    brewery_name: z.string(),
    brewery_slug: z.string(),
    brewery_page_url: z.string(),
    brewery_type: z.string(),
    brewery_label: z.string(),
    country_name: z.string(),
    contact: z.object({
      twitter: z.string().optional(),
      facebook: z.string().optional(),
      instagram: z.string().optional(),
      url: z.string().optional(),
    }),
    location: z.object({
      brewery_city: z.string(),
      brewery_state: z.string(),
      lat: z.number(),
      lng: z.number(),
    }),
    brewery_active: z.number(),
  }),
});
type UntappdBeer = z.infer<typeof UntappdBeer>;

const UntappdSearchResponse = z.object({
  meta: z.object({
    code: z.number(),
    response_time: z.object({
      time: z.number(),
      measure: z.string(),
    }),
    init_time: z.object({
      time: z.number(),
      measure: z.string(),
    }),
  }),
  notifications: z.array(z.any()),
  response: z.object({
    message: z.string(),
    time_taken: z.number(),
    brewery_id: z.number(),
    search_type: z.string(),
    type_id: z.number(),
    search_version: z.number(),
    found: z.number(),
    offset: z.number(),
    limit: z.number(),
    term: z.string(),
    parsed_term: z.string(),
    beers: z.object({
      count: z.number(),
      items: z.array(UntappdBeer),
    }),
    homebrew: z.object({
      count: z.number(),
      items: z.array(z.any()),
    }),
    breweries: z.object({
      count: z.number(),
      items: z.array(z.any()),
    }),
  }),
});
type UntappdSearchResponse = z.infer<typeof UntappdSearchResponse>;

export { searchBeer, UntappdSearchResponse, type UntappdBeer };
