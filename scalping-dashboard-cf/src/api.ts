// ═══════════════════════════════════════════════════════════
// Polygon.io (Massive.com) API Helpers
// ═══════════════════════════════════════════════════════════

import type { BarData } from "./types";

const BASE_URL = "https://api.polygon.io";

// ── Generic GET ──────────────────────────────────────────

export async function apiGet(
  path: string,
  params: Record<string, string>,
  apiKey: string
): Promise<any> {
  const url = new URL(`${BASE_URL}${path}`);
  for (const [k, v] of Object.entries(params)) {
    url.searchParams.set(k, v);
  }
  const resp = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Polygon API ${resp.status}: ${text.slice(0, 200)}`);
  }
  return resp.json();
}

// ── Get Nearest Expiration ───────────────────────────────

export async function getNearestExpiration(
  ticker: string,
  apiKey: string
): Promise<string> {
  const today = new Date().toISOString().slice(0, 10);
  const data = await apiGet("/v3/reference/options/contracts", {
    underlying_ticker: ticker,
    "expiration_date.gte": today,
    expired: "false",
    limit: "1",
    sort: "expiration_date",
    order: "asc",
  }, apiKey);

  const results = data.results || [];
  if (results.length === 0) {
    throw new Error(`No options expirations found for ${ticker}`);
  }
  return results[0].expiration_date;
}

// ── Get Spot Price ───────────────────────────────────────

// Exchange suffix map for Google Finance
const EXCHANGE_MAP: Record<string, string> = {
  SPY: "NYSEARCA", QQQ: "NASDAQ", DIA: "NYSEARCA", IWM: "NYSEARCA",
  // Most individual stocks are on NASDAQ or NYSE — we try NASDAQ first
};

async function googlePrice(ticker: string): Promise<number | null> {
  const exchanges = EXCHANGE_MAP[ticker]
    ? [EXCHANGE_MAP[ticker]]
    : ["NASDAQ", "NYSE", "NYSEARCA"];

  for (const exchange of exchanges) {
    try {
      const resp = await fetch(
        `https://www.google.com/finance/quote/${ticker}:${exchange}`,
        { headers: { "User-Agent": "Mozilla/5.0" } },
      );
      if (!resp.ok) continue;
      const html = await resp.text();
      const match = html.match(/data-last-price="([0-9.]+)"/);
      if (match) return parseFloat(match[1]);
    } catch {
      continue;
    }
  }
  return null;
}

export async function getSpotPrice(
  ticker: string,
  apiKey: string
): Promise<number> {
  const nowSec = Date.now() / 1000;

  // ── SOURCE 1: Yahoo Finance — real-time, no API key ──
  try {
    const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=1m&range=1d`;
    const resp = await fetch(yahooUrl, {
      headers: { "User-Agent": "Mozilla/5.0" },
    });
    if (resp.ok) {
      const data = (await resp.json()) as any;
      const meta = data?.chart?.result?.[0]?.meta;
      const price = meta?.regularMarketPrice;
      const ts = meta?.regularMarketTime; // unix seconds
      if (price && price > 0 && ts && (nowSec - ts) < 300) {
        return price; // fresh Yahoo price — best case
      }
    }
  } catch {
    // fall through
  }

  // ── SOURCE 2: Google Finance — real-time, no API key ──
  try {
    const gPrice = await googlePrice(ticker);
    if (gPrice && gPrice > 0) return gPrice;
  } catch {
    // fall through
  }

  // ── SOURCE 3: Polygon snapshot (may be 15-min delayed) ──
  try {
    const data = await apiGet(
      `/v2/snapshot/locale/us/markets/stocks/tickers/${ticker}`,
      {},
      apiKey
    );
    const t = data.ticker || {};
    const price = t.min?.c || t.day?.c || t.lastTrade?.p;
    if (price && price > 0) return price;
  } catch {
    // fall through
  }

  // ── SOURCE 4: Polygon previous day close ──
  try {
    const data = await apiGet(`/v2/aggs/ticker/${ticker}/prev`, {}, apiKey);
    const results = data.results || [];
    if (results.length > 0 && results[0].c) return results[0].c;
  } catch {
    // fall through
  }

  throw new Error(`Could not get price for ${ticker}`);
}

// ── Get Options Chain ────────────────────────────────────

export async function getOptionsChain(
  ticker: string,
  expiration: string,
  spot: number,
  apiKey: string,
  numStrikes: number = 10
): Promise<[any[], number]> {
  const strikeRange = spot * 0.12;
  const strikeLo = Math.round((spot - strikeRange) * 100) / 100;
  const strikeHi = Math.round((spot + strikeRange) * 100) / 100;

  const allResults: any[] = [];

  const data = await apiGet(`/v3/snapshot/options/${ticker}`, {
    expiration_date: expiration,
    "strike_price.gte": strikeLo.toString(),
    "strike_price.lte": strikeHi.toString(),
    limit: "250",
  }, apiKey);

  allResults.push(...(data.results || []));

  // Handle pagination
  let nextUrl: string | undefined = data.next_url;
  while (nextUrl) {
    if (!nextUrl.includes("apiKey=")) {
      nextUrl += (nextUrl.includes("?") ? "&" : "?") + `apiKey=${apiKey}`;
    }
    const resp = await fetch(nextUrl, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    if (!resp.ok) break;
    const page = await resp.json() as any;
    allResults.push(...(page.results || []));
    nextUrl = page.next_url;
  }

  if (allResults.length === 0) {
    throw new Error(`No options data returned for ${ticker} exp=${expiration}`);
  }

  // Update spot from underlying_asset if available
  let updatedSpot = spot;
  for (const r of allResults) {
    const ua = r.underlying_asset || {};
    if (ua.price) {
      updatedSpot = ua.price;
      break;
    }
  }

  // Get unique strikes sorted by distance from ATM
  const strikesSet = new Set<number>();
  for (const r of allResults) {
    const s = r.details?.strike_price;
    if (s != null) strikesSet.add(s);
  }
  const sortedStrikes = [...strikesSet].sort(
    (a, b) => Math.abs(a - updatedSpot) - Math.abs(b - updatedSpot)
  );
  const selectedStrikes = new Set(sortedStrikes.slice(0, numStrikes));

  // Filter to selected strikes
  const filtered = allResults.filter(
    (r) => selectedStrikes.has(r.details?.strike_price)
  );

  return [filtered, updatedSpot];
}

// ── Get Historical Bars ──────────────────────────────────

export async function getHistoricalBars(
  ticker: string,
  apiKey: string,
  days: number = 5,
  barMinutes: number = 10
): Promise<BarData[]> {
  const toDate = new Date();
  const fromDate = new Date();
  fromDate.setDate(toDate.getDate() - (days + 4)); // extra days for weekends

  const from = fromDate.toISOString().slice(0, 10);
  const to = toDate.toISOString().slice(0, 10);

  const data = await apiGet(
    `/v2/aggs/ticker/${ticker}/range/${barMinutes}/minute/${from}/${to}`,
    { adjusted: "true", sort: "asc", limit: "50000" },
    apiKey
  );

  return (data.results || []) as BarData[];
}
