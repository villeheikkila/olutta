import { Pgmq } from "https://deno.land/x/pgmq@v0.2.1/mod.ts";
import { Client } from "https://deno.land/x/postgres@v0.19.3/client.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { getConfig } from "./config.ts";
import { Context } from "./context.ts";
import * as repository from "./repository/index.ts";
import * as untappd from "./untappd/index.ts";

const BATCH_SIZE = 2;
const VISIBILITY_TIMEOUT_SECONDS = 60;
const QUEUE_NAME = "beer_populate_untappd";
const DLQ_QUEUE_NAME = "beer_populate_untappd_dlq";

async function processMessage(
  ctx: Context,
  msg: BeerPopulateMessage
): Promise<boolean> {
  const beerName = msg.name.replace(/tölkki/i, "").trim();
  const result = await untappd.searchBeer(ctx, beerName);
  if (result) {
    const metadata = await untappd.getBeerMetadata(ctx, result.beer.bid);
    if (!metadata) {
      console.log("failed to fetch metadata for beer");
      return false;
    }
    const res = await repository.storeUntappdBeer(ctx, result, metadata);
    if (!res) {
      console.log("failed to store beer in database");
      return false;
    }
    await repository.storeBeerMapping(ctx, {
      untappedId: res.id,
      alkoId: msg.beer_id,
    });
    if (!res) {
      console.log("failed to link alko product to untappd product");
      return false;
    }
    console.log(`processed beer: ${beerName}`);
    return true;
  } else {
    console.log(`no Untappd match found for: ${beerName}`);
    return false;
  }
}

const BeerPopulateMessage = z.object({
  beer_id: z.string().uuid(),
  manufacturer: z.string(),
  name: z.string(),
});
type BeerPopulateMessage = z.infer<typeof BeerPopulateMessage>;

async function processBeerQueue(ctx: Context) {
  const messages = await ctx.pgmq.msg.readBatch(
    QUEUE_NAME,
    VISIBILITY_TIMEOUT_SECONDS,
    BATCH_SIZE
  );
  for (const rawMessage of messages) {
    if (!rawMessage) {
      console.log("no more messages in queue");
      break;
    }
    const parsedMessage = BeerPopulateMessage.safeParse(rawMessage.message);
    if (!parsedMessage.success) {
      await ctx.pgmq.msg.archive(DLQ_QUEUE_NAME, rawMessage.msgId);
      await ctx.pgmq.msg.send(QUEUE_NAME, { id: rawMessage.msgId });
      return;
    }
    const message = parsedMessage.data;
    console.log(message);
    const success = await processMessage(ctx, message);
    if (!success) {
      await ctx.pgmq.msg.send(DLQ_QUEUE_NAME, rawMessage.message);
      console.log(
        `failed to process beer ${message.manufacturer} ${message.name}, added to DLQ`
      );
    }
    await ctx.pgmq.msg.archive(QUEUE_NAME, rawMessage.msgId);
  }
  await ctx.pgmq.close();
}

Deno.serve(async (req) => {
  const cfg = getConfig();
  if (!cfg.db.url) {
    return new Response(
      JSON.stringify({
        message: "failed to start processing due to missing env",
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
        },
      }
    );
  }
  const pgmq = await Pgmq.new({
    dsn: cfg.db.url,
  });
  const pg = new Client(cfg.db.url);
  await pg.connect();
  EdgeRuntime.waitUntil(
    processBeerQueue({
      pg,
      pgmq,
      cfg,
    })
  );
  return new Response(JSON.stringify({ status: "processing completed..." }), {
    headers: {
      "Content-Type": "application/json",
    },
  });
});
