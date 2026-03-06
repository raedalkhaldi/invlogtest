// ═══════════════════════════════════════════════════════════
// Alpaca Paper Trading API Client
// ═══════════════════════════════════════════════════════════

const BASE = "https://paper-api.alpaca.markets";
const DATA_BASE = "https://data.alpaca.markets";

interface AlpacaAuth {
  key: string;
  secret: string;
}

function headers(auth: AlpacaAuth): Record<string, string> {
  return {
    "APCA-API-KEY-ID": auth.key,
    "APCA-API-SECRET-KEY": auth.secret,
    "Content-Type": "application/json",
  };
}

// ───────────────────────────────────────────────────────────
// OCC Symbol Builder
// MSFT 260320 C 00402500
// ticker(padded 6) + YYMMDD + C/P + strike×1000 (padded 8)
// ───────────────────────────────────────────────────────────

export function buildOccSymbol(
  ticker: string,
  expiration: string,       // "2026-03-20"
  contractType: "CALL" | "PUT",
  strike: number,
): string {
  const t = ticker.toUpperCase();
  const [y, m, d] = expiration.split("-");
  const yy = y.slice(2);
  const cp = contractType === "CALL" ? "C" : "P";
  const s = Math.round(strike * 1000).toString().padStart(8, "0");
  return `${t}${yy}${m}${d}${cp}${s}`;
}

// ───────────────────────────────────────────────────────────
// Account
// ───────────────────────────────────────────────────────────

export interface AlpacaAccount {
  id: string;
  equity: string;
  cash: string;
  buying_power: string;
  portfolio_value: string;
  status: string;
}

export async function getAccount(auth: AlpacaAuth): Promise<AlpacaAccount> {
  const r = await fetch(`${BASE}/v2/account`, { headers: headers(auth) });
  if (!r.ok) throw new Error(`Alpaca account: ${r.status} ${await r.text()}`);
  return r.json() as Promise<AlpacaAccount>;
}

// ───────────────────────────────────────────────────────────
// Place Option Order
// ───────────────────────────────────────────────────────────

export interface AlpacaOrder {
  id: string;
  status: string;
  symbol: string;
  qty: string;
  filled_qty: string;
  filled_avg_price: string | null;
  side: string;
  type: string;
  order_class: string;
}

export async function placeOptionOrder(
  auth: AlpacaAuth,
  occSymbol: string,
  qty: number,
  side: "buy" | "sell",
): Promise<AlpacaOrder> {
  const body = {
    symbol: occSymbol.trim(),
    qty: qty.toString(),
    side,
    type: "market",
    time_in_force: "day",
  };
  const r = await fetch(`${BASE}/v2/orders`, {
    method: "POST",
    headers: headers(auth),
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`Alpaca order: ${r.status} ${await r.text()}`);
  return r.json() as Promise<AlpacaOrder>;
}

// ───────────────────────────────────────────────────────────
// Get Positions
// ───────────────────────────────────────────────────────────

export interface AlpacaPosition {
  asset_id: string;
  symbol: string;
  qty: string;
  avg_entry_price: string;
  current_price: string;
  market_value: string;
  unrealized_pl: string;
  unrealized_plpc: string;
  side: string;
}

export async function getPositions(auth: AlpacaAuth): Promise<AlpacaPosition[]> {
  const r = await fetch(`${BASE}/v2/positions`, { headers: headers(auth) });
  if (!r.ok) throw new Error(`Alpaca positions: ${r.status} ${await r.text()}`);
  return r.json() as Promise<AlpacaPosition[]>;
}

// ───────────────────────────────────────────────────────────
// Close Position (sell all shares of a symbol)
// ───────────────────────────────────────────────────────────

export async function closePosition(
  auth: AlpacaAuth,
  symbolOrId: string,
): Promise<AlpacaOrder> {
  const r = await fetch(`${BASE}/v2/positions/${encodeURIComponent(symbolOrId)}`, {
    method: "DELETE",
    headers: headers(auth),
  });
  if (!r.ok) throw new Error(`Alpaca close: ${r.status} ${await r.text()}`);
  return r.json() as Promise<AlpacaOrder>;
}

// ───────────────────────────────────────────────────────────
// Get Order by ID (to check fill status)
// ───────────────────────────────────────────────────────────

export async function getOrder(auth: AlpacaAuth, orderId: string): Promise<AlpacaOrder> {
  const r = await fetch(`${BASE}/v2/orders/${orderId}`, { headers: headers(auth) });
  if (!r.ok) throw new Error(`Alpaca getOrder: ${r.status} ${await r.text()}`);
  return r.json() as Promise<AlpacaOrder>;
}

// ───────────────────────────────────────────────────────────
// Get Live Stock Price (Alpaca Market Data)
// ───────────────────────────────────────────────────────────

export async function getStockPrice(auth: AlpacaAuth, ticker: string): Promise<number | null> {
  try {
    const r = await fetch(`${DATA_BASE}/v2/stocks/${encodeURIComponent(ticker)}/trades/latest`, {
      headers: {
        "APCA-API-KEY-ID": auth.key,
        "APCA-API-SECRET-KEY": auth.secret,
      },
    });
    if (!r.ok) return null;
    const data = await r.json() as { trade?: { p?: number } };
    return data?.trade?.p ?? null;
  } catch {
    return null;
  }
}

// ───────────────────────────────────────────────────────────
// Check if market is open
// ───────────────────────────────────────────────────────────

export async function isMarketOpen(auth: AlpacaAuth): Promise<boolean> {
  const r = await fetch(`${BASE}/v2/clock`, { headers: headers(auth) });
  if (!r.ok) return false;
  const data = await r.json() as { is_open: boolean };
  return data.is_open;
}
