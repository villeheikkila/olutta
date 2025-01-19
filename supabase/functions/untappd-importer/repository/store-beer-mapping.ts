import { Context } from "../context.ts";

const query = `
INSERT INTO beer_alko_beer_untappd (
  beer_untappd_id,
  beer_alko_id
) VALUES (
  $1, $2
)
ON CONFLICT (beer_alko_id, beer_untappd_id) DO UPDATE SET
  updated_at = now()
RETURNING *`;

const storeBeerMapping = async (
  ctx: Context,
  mapping: {
    untappedId: number;
    alkoId: string;
  }
): Promise<{ beer_untappd_id: string; beer_alko_id: string } | null> => {
  const values = [mapping.untappedId, mapping.alkoId];
  const result = await ctx.pg.queryObject<{
    beer_untappd_id: string;
    beer_alko_id: string;
  }>(query, values);
  return result.rows[0] ?? null;
};

export { storeBeerMapping };
