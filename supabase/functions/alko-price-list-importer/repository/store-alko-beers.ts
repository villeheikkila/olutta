import { AlkoBeerProduct } from "../alko/parse-alko-xlsx.ts";
import { Context } from "../context.ts";

async function storeAlkoBeers(ctx: Context, beers: AlkoBeerProduct[]) {
  const values = beers
    .map(
      (beer) => `(
    DEFAULT,
    '${beer.numero}',
    '${beer.nimi.replace(/'/g, "''")}',
    '${beer.valmistaja.replace(/'/g, "''")}',
    '${beer.pullokoko}',
    ${beer.hinta},
    ${beer.litrahinta || "NULL"},
    '${beer.tyyppi}',
    ${beer.oluttyyppi ? `'${beer.oluttyyppi.replace(/'/g, "''")}'` : "NULL"},
    ${
      beer.valmistusmaa ? `'${beer.valmistusmaa.replace(/'/g, "''")}'` : "NULL"
    },
    ${beer.alkoholiprosentti},
    ${beer.kantavierrep || "NULL"},
    ${beer.vari_ebc || "NULL"},
    ${beer.katkerot_ebu || "NULL"},
    ${
      beer.pakkaustyyppi
        ? `'${beer.pakkaustyyppi.replace(/'/g, "''")}'`
        : "NULL"
    },
    ${beer.energia_kcal || "NULL"},
    ${beer.ean ? `'${beer.ean}'` : "NULL"}
  )`
    )
    .join(",");

  const batchQuery = `
    INSERT INTO beer_alko (
      id, product_code, name, manufacturer, container_size, 
      price, price_per_liter, type, beer_style, country, 
      alcohol_percentage, original_gravity, color_ebc, 
      bitterness_ibu, package_type, energy_kcal, ean
    ) 
    VALUES ${values}
    ON CONFLICT (product_code) 
    DO UPDATE SET 
      name = EXCLUDED.name,
      manufacturer = EXCLUDED.manufacturer,
      container_size = EXCLUDED.container_size,
      price = EXCLUDED.price,
      price_per_liter = EXCLUDED.price_per_liter,
      type = EXCLUDED.type,
      beer_style = EXCLUDED.beer_style,
      country = EXCLUDED.country,
      alcohol_percentage = EXCLUDED.alcohol_percentage,
      original_gravity = EXCLUDED.original_gravity,
      color_ebc = EXCLUDED.color_ebc,
      bitterness_ibu = EXCLUDED.bitterness_ibu,
      package_type = EXCLUDED.package_type,
      energy_kcal = EXCLUDED.energy_kcal,
      ean = EXCLUDED.ean,
      updated_at = CURRENT_TIMESTAMP
    RETURNING id
  `;

  return await ctx.pg.queryObject(batchQuery);
}

export { storeAlkoBeers };
