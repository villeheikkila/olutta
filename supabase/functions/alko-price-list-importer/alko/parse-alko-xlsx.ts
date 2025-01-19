// @deno-types="https://cdn.sheetjs.com/xlsx-0.20.3/package/types/index.d.ts"
import * as XLSX from "https://cdn.sheetjs.com/xlsx-0.20.3/package/xlsx.mjs";
import { z } from "https://deno.land/x/zod@v3.24.1/mod.ts";

function parseAlkoXLSX(buffer: ArrayBuffer) {
  const workbook = XLSX.read(buffer);
  const firstSheetName = workbook.SheetNames[0];
  const worksheet = workbook.Sheets[firstSheetName];
  const jsonData = XLSX.utils.sheet_to_json(worksheet, {
    header: [
      "numero",
      "nimi",
      "valmistaja",
      "pullokoko",
      "hinta",
      "litrahinta",
      "uutuus",
      "hinnastojarjestyskoodi",
      "tyyppi",
      "alatyyppi",
      "erityisryhma",
      "oluttyyppi",
      "valmistusmaa",
      "alue",
      "vuosikerta",
      "etikettimerkintoja",
      "huomautus",
      "rypaleet",
      "luonnehdinta",
      "pakkaustyyppi",
      "suljentatyyppi",
      "alkoholiprosentti",
      "hapot",
      "sokeri",
      "kantavierrep",
      "vari_ebc",
      "katkerot_ebu",
      "energia_kcal",
      "valikoima",
      "ean",
    ],
    raw: false,
  });
  const beerProducts = jsonData.filter(
    (row: unknown) =>
      typeof row === "object" &&
      row !== null &&
      "tyyppi" in row &&
      (row as { tyyppi: string }).tyyppi === "oluet"
  );
  return z.array(AlkoBeerProduct).safeParse(beerProducts);
}

const numberFromString = z.string().transform((val) => {
  const parsed = Number(val.replace(",", "."));
  return isNaN(parsed) ? null : parsed;
});

const AlkoBeerProduct = z.object({
  numero: z.string(),
  nimi: z.string(),
  valmistaja: z.string(),
  pullokoko: z.string(),
  hinta: numberFromString,
  litrahinta: numberFromString.optional(),
  uutuus: z.string().optional().nullable(),
  hinnastojarjestyskoodi: z.string().optional(),
  tyyppi: z.string(),
  alatyyppi: z.string().optional(),
  erityisryhma: z.string().optional().nullable(),
  oluttyyppi: z.string().optional().nullable(),
  valmistusmaa: z.string().optional(),
  alue: z.string().optional().nullable(),
  vuosikerta: z.string().optional().nullable(),
  etikettimerkintoja: z.string().optional().nullable(),
  huomautus: z.string().optional().nullable(),
  rypaleet: z.string().optional().nullable(),
  luonnehdinta: z.string().optional(),
  pakkaustyyppi: z.string().optional(),
  suljentatyyppi: z.string().optional(),
  alkoholiprosentti: numberFromString,
  hapot: numberFromString.optional(),
  sokeri: numberFromString.optional(),
  kantavierrep: numberFromString.optional(),
  vari_ebc: numberFromString.optional(),
  katkerot_ebu: numberFromString.optional(),
  energia_kcal: numberFromString.optional(),
  valikoima: z.string().optional(),
  ean: z.string().optional(),
});
type AlkoBeerProduct = z.infer<typeof AlkoBeerProduct>;

export { parseAlkoXLSX, type AlkoBeerProduct };
