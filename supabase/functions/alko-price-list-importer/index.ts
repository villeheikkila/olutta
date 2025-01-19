import { Client } from "https://deno.land/x/postgres/mod.ts";
import * as alko from "./alko/index.ts";
import { getConfig } from "./context.ts";
import * as repository from "./repository/index.ts";

Deno.serve(async () => {
  const cfg = getConfig();
  const buffer = await alko.fetchPricingTable();
  if (!buffer) {
    return new Response(
      JSON.stringify({
        error: "fetching pricing table failed",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
  const parsedData = alko.parseAlkoXLSX(buffer);
  if (!parsedData.success) {
    return new Response(
      JSON.stringify({
        error: "parsing xslx failed",
        details: parsedData.error,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
  const pg = new Client(cfg.pg.url);
  await pg.connect();
  const stores = await alko.fetchStores({ pg, cfg });
  const storedBeers = await repository.storeAlkoBeers(
    { pg, cfg },
    parsedData.data
  );

  const storedStores = await repository.upsertStores({ pg, cfg }, stores);
  await pg.end();
  return new Response(
    JSON.stringify({
      beers: storedBeers.rowCount,
      stores: storedStores.length,
    }),
    {
      headers: { "Content-Type": "application/json" },
    }
  );
});
