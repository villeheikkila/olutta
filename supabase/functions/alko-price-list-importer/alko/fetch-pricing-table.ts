const PRICING_TABLE_URL =
  "https://www.alko.fi/INTERSHOP/static/WFS/Alko-OnlineShop-Site/-/Alko-OnlineShop/fi_FI/Alkon%20Hinnasto%20Tekstitiedostona/alkon-hinnasto-tekstitiedostona.xlsx";

async function fetchPricingTable(): Promise<ArrayBuffer | null> {
  console.log("Starting download...");
  const response = await fetch(PRICING_TABLE_URL);
  if (!response.ok) {
    console.log(`error occured while fetching pricing table, ${response}`);
    return null;
  }
  return await response.arrayBuffer();
}

export { fetchPricingTable };
