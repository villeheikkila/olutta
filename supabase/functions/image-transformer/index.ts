import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { v2 as cloudinary } from "npm:cloudinary@1.41.3";

const app = async () => {
  const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
  const cloudName = Deno.env.get("CLOUDINARY_CLOUD_NAME");
  const apiKey = Deno.env.get("CLOUDINARY_API_KEY");
  const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET");

  if (!databaseUrl || !cloudName || !apiKey || !apiSecret) {
    return createResponse({ error: "missing environment variables" }, 500);
  }

  cloudinary.config({
    cloud_name: cloudName,
    api_key: apiKey,
    api_secret: apiSecret,
  });

  const pg = new Client(databaseUrl);
  try {
    await pg.connect();
    const updatedProducts = await updateProductImages(pg);
    return createResponse({
      products: updatedProducts.length,
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

async function uploadToCloudinary(
  imageUrl: string,
  productId: string
): Promise<string | null> {
  try {
    const uploadResult = await cloudinary.uploader.upload(imageUrl, {
      public_id: `beer/${productId}`,
      format: "png",
      transformation: [
        { width: 256, crop: "limit" },
        { dpr: "2.0" }, // For retina displays
        { quality: "auto:best" }, // Best quality for PNG
        { flags: "preserve_transparency" }, // Ensure alpha channel is preserved
      ],
    });
    return uploadResult.secure_url;
  } catch (error) {
    console.error("Error uploading to Cloudinary:", error);
    return null;
  }
}

async function updateProductImages(pg: Client) {
  const { rows: products } = await pg.queryObject<{
    id: string;
    alko_image_url: string;
  }>`
    SELECT id, alko_image_url 
    FROM beer_alko where image_url is null and alko_image_url IS NOT NULL
  `;

  const updatedProducts = [];

  for (const product of products) {
    const newImageUrl = await uploadToCloudinary(
      product.alko_image_url,
      product.id
    );

    if (newImageUrl) {
      const result = await pg.queryObject<{ id: string }>({
        text: `
          UPDATE beer_alko 
          SET image_url = $1
          WHERE id = $2
          RETURNING id
        `,
        args: [newImageUrl, product.id],
      });

      if (result.rows.length > 0) {
        updatedProducts.push(result.rows[0]);
      }
    }
  }

  return updatedProducts;
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
