import * as jwt from "https://deno.land/x/djwt@v3.0.1/mod.ts";
import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";

const app = async () => {
  const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
  const encodedPrivateKey = Deno.env.get("APPLE_PRIVATE_KEY_BASE64");
  if (!databaseUrl || !encodedPrivateKey) {
    return createResponse({ error: "missing environment variables" }, 500);
  }

  const pg = new Client(databaseUrl);
  try {
    await pg.connect();
    const privateKey = atob(encodedPrivateKey);
    const mapKitToken = await generateMapKitToken(privateKey);
    const updatedStores = await updateStoresWithMapKitIds(pg, mapKitToken);
    return createResponse({
      stores: updatedStores.length,
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

async function generateMapKitToken(privateKey: string) {
  const teamId = "J9S7QG9SVR";
  const keyId = "8GH6TGHXB8";

  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = base64ToArrayBuffer(pemContents);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    true,
    ["sign"]
  );

  const token = await jwt.create(
    {
      alg: "ES256",
      typ: "JWT",
      kid: keyId,
    },
    {
      iss: teamId,
      iat,
      exp,
    },
    cryptoKey
  );

  const response = await fetch("https://maps-api.apple.com/v1/token", {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const data = await response.json();
  return data.accessToken;
}

async function searchMapKit(
  query: string,
  latitude: number,
  longitude: number,
  accessToken: string
): Promise<string[]> {
  const url = new URL("https://maps-api.apple.com/v1/search");
  url.searchParams.set("q", query);
  url.searchParams.set("searchLocation", `${latitude},${longitude}`);

  try {
    const response = await fetch(url.toString(), {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return data.results.map((result: { id: string }) => result.id);
  } catch (error) {
    console.error("Error searching MapKit:", error);
    return [];
  }
}

async function updateStoresWithMapKitIds(pg: Client, mapKitToken: string) {
  const { rows: stores } = await pg.queryObject<{
    oid: string;
    latitude: number;
    longitude: number;
  }>`
    SELECT oid, latitude, longitude 
    FROM alko_store 
    WHERE mapkit_id IS NULL
  `;

  const updatedStores = [];

  for (const store of stores) {
    const mapKitIds = await searchMapKit(
      "Alko",
      store.latitude,
      store.longitude,
      mapKitToken
    );

    if (mapKitIds.length > 0) {
      const mapKitId = mapKitIds[0];

      const result = await pg.queryObject<{ oid: string }>({
        text: `
          UPDATE alko_store 
          SET mapkit_id = $1
          WHERE oid = $2
          RETURNING oid
        `,
        args: [mapKitId, store.oid],
      });

      if (result.rows.length > 0) {
        updatedStores.push(result.rows[0]);
      }
    }
  }

  return updatedStores;
}

function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

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
