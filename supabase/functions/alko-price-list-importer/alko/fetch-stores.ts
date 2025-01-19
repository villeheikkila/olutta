import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { Context } from "../context.ts";

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
    }),
  ),
});
type AlkoStore = z.infer<typeof AlkoStore>;

async function alkoApi(
  apiKey: string,
  endpoint: string,
  options: RequestInit = {},
) {
  const agent = Deno.env.get("A_AGENT");
  const baseUrl = Deno.env.get("A_BASE_URL");
  const url = `${baseUrl}${endpoint}`;
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json",
    "x-api-key": apiKey,
    "x-alko-mobile": `${agent}/1.18.1 ios/18.2.1`,
    "Accept-Language": "en-GB,en,q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "User-Agent": `${agent} CFNetwork/1568.300.101 Darwin/24.2.0`,
    ...options.headers,
  };
  return await fetch(url, {
    ...options,
    headers,
  });
}

async function fetchStores(ctx: Context): Promise<AlkoStore[]> {
  const response = await alkoApi(ctx.cfg.alko.apiKey, "/stores");
  const data = await response.json();
  const parsedData = AlkoStore.array().safeParse(data);
  if (!parsedData.success) {
    console.error(parsedData.error);
    return [];
  }
  return parsedData.data;
}

export { type AlkoStore, fetchStores };
