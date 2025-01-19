import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Config = {
  db: {
    url: string;
  };
  untappd: {
    clientId: string;
    clientSecret: string;
  };
};

function getConfig(): Config {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  const clientId = Deno.env.get("UNTAPPD_CLIENT_ID");
  const clientSecret = Deno.env.get("UNTAPPD_CLIENT_SECRET");
  if (!dbUrl) {
    throw new Error("Missing SUPABASE_DB_URL environment variable");
  }
  if (!clientId) {
    throw new Error("Missing UNTAPPD_CLIENT_ID environment variable");
  }
  if (!clientSecret) {
    throw new Error("Missing UNTAPPD_CLIENT_SECRET environment variable");
  }
  return {
    db: {
      url: dbUrl,
    },
    untappd: {
      clientId,
      clientSecret,
    },
  };
}

export { getConfig, type Config };
