import { z } from "https://deno.land/x/zod@v3.24.1/mod.ts";
import { Context } from "../context.ts";

async function getBeerMetadata(
  ctx: Context,
  bid: number
): Promise<BeerMetadata | null> {
  try {
    const response = await fetch(
      `https://api.untappd.com/v4/beer/info/${bid}?client_id=${ctx.cfg.untappd.clientId}&client_secret=${ctx.cfg.untappd.clientSecret}`
    );
    const data = await response.json();
    const parsed = UntappedBeerMetadataResponse.safeParse(data);
    if (!parsed.success) {
      console.error("error parsing Untappd response:", parsed.error);
      return null;
    }
    return {
      rating_count: parsed.data.response.beer.rating_count,
      rating_score: parsed.data.response.beer.rating_score,
    };
  } catch (err) {
    console.error("error loading response:", err);
    return null;
  }
}

type BeerMetadata = {
  rating_count: number;
  rating_score: number;
};

const UntappedBeerMetadataResponse = z.object({
  response: z.object({
    beer: z.object({
      bid: z.number(),
      beer_name: z.string(),
      beer_label: z.string().url(),
      beer_label_hd: z.string().url(),
      beer_abv: z.number(),
      beer_ibu: z.number(),
      beer_description: z.string(),
      beer_style: z.string(),
      is_in_production: z.number(),
      beer_slug: z.string(),
      is_homebrew: z.number(),
      created_at: z.string(),
      rating_count: z.number(),
      rating_score: z.number(),
      stats: z.object({
        total_count: z.number(),
        monthly_count: z.number(),
        total_user_count: z.number(),
        user_count: z.number(),
      }),
      brewery: z.object({
        brewery_id: z.number(),
        brewery_name: z.string(),
        brewery_slug: z.string(),
        brewery_type: z.string(),
        brewery_page_url: z.string(),
        brewery_label: z.string().url(),
        country_name: z.string(),
        location: z.object({
          brewery_city: z.string(),
          brewery_state: z.string(),
          lat: z.number(),
          lng: z.number(),
        }),
      }),
    }),
  }),
});
export { getBeerMetadata, type BeerMetadata };
