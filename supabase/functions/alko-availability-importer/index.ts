import { Pgmq } from "https://deno.land/x/pgmq@v0.2.1/mod.ts";
import { PoolClient } from "https://deno.land/x/postgres@v0.19.3/client.ts";
import { Transaction } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { Pool } from "https://deno.land/x/postgres@v0.19.3/pool.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const POOL_SIZE = 1;
const BATCH_SIZE = 5;
const VISIBILITY_TIMEOUT_SECONDS = 60;
const QUEUE_NAME = "beer_populate_alko_availability";
const DLQ_QUEUE_NAME = "beer_populate_alko_availability_dlq";

async function processMessage(
  transaction: Transaction,
  message: Message,
): Promise<boolean> {
  try {
    const result = await transaction.queryObject<{ product_code: string }>`
      SELECT product_code FROM beer_alko WHERE id = ${message.beer_id} limit 1
    `;
    const productCode = result.rows[0]?.product_code;
    if (!productCode) {
      throw new Error("beer not found");
    }

    const apiKey = Deno.env.get("ALKO_API_KEY")!;
    if (!apiKey) {
      throw new Error("Missing Alko API key");
    }

    const res = await queryAlkoStoreAvailability(apiKey, productCode);
    const data = await res.json();
    const availability = z.array(StoreAvailabilitySchema).safeParse(data);
    if (!availability.success) {
      console.error("Invalid availability data:", availability.error);
      throw new Error("invalid availability data");
    }
    const storeIds = availability.data.map((store) => store.id);
    console.log("storeIds", storeIds);
    const storeMapping = await transaction.queryObject<{
      id: string;
      oid: string;
    }>(
      `
      SELECT id, oid FROM alko_store WHERE oid = ANY($1)
    `,
      [storeIds],
    );
    const storeOidToUuid = new Map(
      storeMapping.rows.map((row) => [row.oid, row.id]),
    );
    const inventoryData = availability.data
      .filter((store) => storeOidToUuid.has(store.id))
      .map((store) => ({
        store_id: storeOidToUuid.get(store.id)!,
        beer_id: message.beer_id,
        product_count: store?.count ?? null,
      }));
    if (inventoryData.length === 0) {
      return true;
    }
    const columns = ["store_id", "beer_id", "product_count"];
    const { text: placeholders, values } = generateBulkInsert(
      inventoryData,
      columns,
    );
    const query = `
      INSERT INTO store_inventory (${columns.join(", ")})
      VALUES ${placeholders}
      ON CONFLICT (store_id, beer_id) 
      DO UPDATE SET 
        product_count = EXCLUDED.product_count
    `;
    await transaction.queryObject(query, values);

    const webAvailability = await queryAlkoWebStoreAvailability(
      apiKey,
      productCode,
    );
    const webStoreInventory = webAvailability[0];
    console.log("webStoreInventory", webStoreInventory);
    if (webStoreInventory) {
      const query = `
        INSERT INTO webstore_invetory (
          beer_id,
          status_code,
          message_code,
          estimated_availability_date,
          delivery_min,
          delivery_max,
          status_en,
          status_fi,
          status_sv,
          status_message
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
        )
        ON CONFLICT (beer_id) DO UPDATE SET
          status_code = EXCLUDED.status_code,
          message_code = EXCLUDED.message_code,
          estimated_availability_date = EXCLUDED.estimated_availability_date,
          delivery_min = EXCLUDED.delivery_min,
          delivery_max = EXCLUDED.delivery_max,
          status_en = EXCLUDED.status_en,
          status_fi = EXCLUDED.status_fi,
          status_sv = EXCLUDED.status_sv,
          status_message = EXCLUDED.status_message,
          updated_at = now()
      `;
      const values = [
        message.beer_id,
        webStoreInventory.statusCode,
        webStoreInventory.messageCode,
        webStoreInventory.estimatedAvailabilityDate
          ? new Date(webStoreInventory.estimatedAvailabilityDate)
          : null,
        webStoreInventory.delivery?.min ?? null,
        webStoreInventory.delivery?.max ?? null,
        webStoreInventory.status.en,
        webStoreInventory.status.fi,
        webStoreInventory.status.sv,
        webStoreInventory.statusMessage,
      ];

      try {
        await transaction.queryObject(query, values);
      } catch (error) {
        console.error("Error inserting webstore inventory:", error);
        throw error;
      }
    }
    return true;
  } catch (error) {
    console.error("Database query error:", error);
    return false;
  }
}

type ColumnValue = string | number | Date | boolean | null;

function generateBulkInsert(
  items: Record<string, ColumnValue>[],
  columns: (string | number)[],
) {
  const values: ColumnValue[] = [];
  const placeholders = items
    .map((_, itemIndex) => {
      const itemPlaceholders = columns
        .map((_, colIndex) => `$${itemIndex * columns.length + colIndex + 1}`)
        .join(", ");
      return `(${itemPlaceholders})`;
    })
    .join(", ");

  items.forEach((item) => {
    columns.forEach((col) => {
      values.push(item[col]);
    });
  });

  return {
    text: placeholders,
    values,
  };
}

async function queryAlkoStoreAvailability(apiKey: string, id: string) {
  const agent = Deno.env.get("A_AGENT");
  const baseUrl = Deno.env.get("A_BASE_URL");
  const url = `${baseUrl}/v1/availability/${id}?lang=fi`;
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json",
    "x-api-key": apiKey,
    "x-alko-mobile": `${agent}/1.18.1 ios/18.2.1`,
    "Accept-Language": "en-GB,en,q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "User-Agent": `${agent} CFNetwork/1568.300.101 Darwin/24.2.0`,
  };
  return await fetch(url, {
    headers,
  });
}

async function queryAlkoWebStoreAvailability(
  apiKey: string,
  id: string,
): Promise<ProductStatus> {
  const agent = Deno.env.get("A_AGENT");
  const baseUrl = Deno.env.get("A_BASE_URL");
  const url = `${baseUrl}/v1/webshopAvailability?products=${id}&lang=fi`;
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json",
    "x-api-key": apiKey,
    "x-alko-mobile": `${agent}/1.18.1 ios/18.2.1`,
    "Accept-Language": "en-GB,en,q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "User-Agent": `${agent} CFNetwork/1568.300.101 Darwin/24.2.0`,
  };
  const res = await fetch(url, {
    headers,
  });
  const webAvailabilityResData = await res.json();
  const webAvailabilityResDataParsed = ProductStatus.safeParse(
    webAvailabilityResData,
  );
  if (!webAvailabilityResDataParsed.success) {
    console.error("Invalid web availability data:", webAvailabilityResData);
    throw new Error("invalid web availability data");
  }
  return webAvailabilityResDataParsed.data;
}

const ProductStatus = z.array(
  z.object({
    estimatedAvailabilityDate: z.string().optional(),
    statusCode: z.string(),
    messageCode: z.string(),
    productId: z.string(),
    delivery: z
      .object({
        min: z.number(),
        max: z.number(),
      })
      .optional(),
    status: z.object({
      en: z.string(),
      fi: z.string(),
      sv: z.string(),
    }),
    statusMessage: z.string(),
  }),
);

type ProductStatus = z.infer<typeof ProductStatus>;

const StoreAvailabilitySchema = z.object({
  id: z.string(),
  count: z.string().nullable().optional(),
});

async function processMessageWithTransaction(
  client: PoolClient,
  pgmq: Pgmq,
  rawMessage: any,
) {
  const transaction = client.createTransaction("process_message");
  try {
    await transaction.begin();
    const parsedMessage = Message.safeParse(rawMessage.message);
    if (!parsedMessage.success) {
      throw new Error("Invalid message format");
    }
    const success = await processMessage(transaction, parsedMessage.data);
    if (!success) {
      throw new Error("Processing failed");
    }
    await pgmq.msg.archive(QUEUE_NAME, rawMessage.msgId);
    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    await pgmq.msg.archive(QUEUE_NAME, rawMessage.msgId);
    await pgmq.msg.send(DLQ_QUEUE_NAME, rawMessage);
    throw error;
  }
}

const Message = z.object({
  beer_id: z.string().uuid(),
});
type Message = z.infer<typeof Message>;

async function processQueue(pool: Pool, pgmq: Pgmq) {
  try {
    const messages = await pgmq.msg.readBatch(
      QUEUE_NAME,
      VISIBILITY_TIMEOUT_SECONDS,
      BATCH_SIZE,
    );
    await Promise.all(
      messages.map(async (rawMessage) => {
        const client = await pool.connect();
        try {
          await processMessageWithTransaction(client, pgmq, rawMessage);
        } catch (error) {
          console.error("Error processing message:", error);
        } finally {
          client.release();
        }
      }),
    );
  } catch (error) {
    console.error("Queue processing error:", error);
    throw error;
  } finally {
    await pgmq.close();
    await pool.end();
  }
}

Deno.serve(async () => {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) {
    return new Response(
      JSON.stringify({ message: "Missing database configuration" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
  const pool = new Pool(dbUrl, POOL_SIZE, false);
  const pgmq = await Pgmq.new({ dsn: dbUrl });
  try {
    EdgeRuntime.waitUntil(processQueue(pool, pgmq));
    return new Response(JSON.stringify({ status: "Processing started" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Failed to start processing:", error);
    return new Response(
      JSON.stringify({
        message: "Failed to start processing",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
