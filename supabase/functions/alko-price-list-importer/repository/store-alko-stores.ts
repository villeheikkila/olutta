import * as alko from "../alko/index.ts";
import { Context } from "../context.ts";

async function upsertStores(ctx: Context, stores: alko.AlkoStore[]) {
  const columns = [
    "id",
    "name",
    "address",
    "city",
    "postal_code",
    "latitude",
    "longitude",
    "outlet_type",
  ];
  const storeRecords = stores.map((store) => ({
    id: store.id,
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
  const res = await ctx.pg.queryObject<{ id: string }[]>(
    `
    INSERT INTO alko_store (${columns.join(", ")}) 
    VALUES ${placeholders}
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      address = EXCLUDED.address,
      city = EXCLUDED.city,
      postal_code = EXCLUDED.postal_code,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      outlet_type = EXCLUDED.outlet_type
    RETURNING id;
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

export { upsertStores };
