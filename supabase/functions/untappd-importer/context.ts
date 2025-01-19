import { Pgmq } from "https://deno.land/x/pgmq@v0.2.1/mod.ts";
import { Client } from "https://deno.land/x/postgres@v0.19.3/client.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Config } from "./config.ts";

type Context = {
  pg: Client;
  pgmq: Pgmq;
  cfg: Config;
};

export { type Context };
