import { gzip } from "https://deno.land/x/compress@v0.5.5/mod.ts";
import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const pool = new Pool(Deno.env.get("SUPABASE_DB_URL")!, 1);

async function compressResponse(data: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  return gzip(encoder.encode(data));
}

Deno.serve(async (req) => {
  const acceptEncoding = req.headers.get("accept-encoding") || "";
  const supportsGzip = acceptEncoding.includes("gzip");

  try {
    const connection = await pool.connect();

    try {
      // Query the materialized view instead of the function
      const result = await connection.queryObject<{
        data: unknown;
      }>`SELECT data from materialized_view_response`;

      const jsonData = JSON.stringify(result.rows[0]?.data);

      const headers = new Headers({
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=300",
        "Vary": "Accept-Encoding",
      });

      if (supportsGzip) {
        const compressedData = await compressResponse(jsonData);
        headers.set("Content-Encoding", "gzip");
        return new Response(compressedData, { headers });
      }

      return new Response(jsonData, { headers });
    } finally {
      connection.release();
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as any).message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});

// Handle shutdown gracefully
Deno.addSignalListener("SIGINT", async () => {
  await pool.end();
  Deno.exit();
});
