import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

const app = async () => {
  const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
  const alkoApiKey = Deno.env.get("ALKO_API_KEY");
  if (!databaseUrl || !alkoApiKey) {
    return createResponse({ error: "missing environment variables" }, 500);
  }
  const pg = new Client(databaseUrl);
  try {
    await pg.connect();
    const stores = await fetchStores(alkoApiKey);
    const filtered = stores.filter((store) => store.outletType === "myymalat");
    const storedStores = await upsertStores(pg, filtered);
    return createResponse({
      stores: storedStores.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("error:", error);
    return createResponse(
      {
        error: "Internal server error",
      },
      500
    );
  } finally {
    try {
      await pg.end();
    } catch (error) {
      console.error("error closing database connection:", error);
    }
  }
};

function createResponse(data: object, status: number = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-cache",
    },
  });
}

Deno.serve(app);

const AlkoStore = z.object({
  id: z.string(),
  address: z.string(),
  city: z.string(),
  latitude: z.number(),
  longitude: z.number(),
  outletType: z.string(),
  name: z.string(),
  postalCode: z.string(),
  openDays: z.array(
    z.object({
      hours: z.string(),
      date: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .transform((date) => new Date(date)),
    })
  ),
});
type AlkoStore = z.infer<typeof AlkoStore>;

const BASE_URL = "https://mobile-api.alko.fi/v1";

async function alkoApi(
  apiKey: string,
  endpoint: string,
  options: RequestInit = {}
) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = {
    "x-api-key": apiKey,
    "Content-Type": "application/json",
    ...options.headers,
  };
  return await fetch(url, {
    ...options,
    headers,
  });
}

async function fetchStores(alkoApiKey: string): Promise<AlkoStore[]> {
  const response = await alkoApi(alkoApiKey, "/stores");
  const data = await response.json();
  const parsedData = AlkoStore.array().safeParse(data);
  if (!parsedData.success) {
    console.error(parsedData.error);
    return [];
  }
  return parsedData.data;
}

async function upsertStores(pg: Client, stores: AlkoStore[]) {
  const columns = [
    "oid",
    "name",
    "address",
    "city",
    "postal_code",
    "latitude",
    "longitude",
    "outlet_type",
  ];
  const storeRecords = stores.map((store) => ({
    oid: store.id,
    name: store.name,
    address: store.address,
    city: store.city,
    postal_code: store.postalCode,
    latitude: store.latitude,
    longitude: store.longitude,
    outlet_type: store.outletType,
  }));
  const { text: placeholders, values } = generateBulkInsert(
    storeRecords,
    columns
  );
  const res = await pg.queryObject<{ oid: string }[]>(
    `
    INSERT INTO alko_store (${columns.join(", ")}) 
    VALUES ${placeholders}
    ON CONFLICT (oid) DO UPDATE SET
      name = EXCLUDED.name,
      address = EXCLUDED.address,
      city = EXCLUDED.city,
      postal_code = EXCLUDED.postal_code,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      outlet_type = EXCLUDED.outlet_type
    RETURNING oid;
      `,
    values
  );
  return res.rows;
}

type ColumnValue = string | number | Date | boolean | null;

function generateBulkInsert(
  items: Record<string, ColumnValue>[],
  columns: string[]
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
