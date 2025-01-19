import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";

type Config = {
  pg: {
    url: string;
  };
  alko: {
    apiKey: string;
  };
};

function getConfig(): Config {
  return {
    pg: {
      url: Deno.env.get("SUPABASE_DB_URL")!,
    },
    alko: {
      apiKey:
        Deno.env.get("ALKO_API_KEY") ??
        "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0",
    },
  };
}

type Context = {
  pg: Client;
  cfg: Config;
};

export { getConfig, type Config, type Context };
