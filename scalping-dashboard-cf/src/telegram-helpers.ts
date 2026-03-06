// ═══════════════════════════════════════════════════════════
// Shared Telegram Bot Helpers
// Used by both webhook handler and cron endpoint.
// ═══════════════════════════════════════════════════════════

// ── Telegram API ─────────────────────────────────────────
export async function tgSend(
  token: string,
  method: string,
  body: Record<string, unknown>,
): Promise<{ ok: boolean; result?: any }> {
  const resp = await fetch(
    `https://api.telegram.org/bot${token}/${method}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
  );
  return resp.json() as Promise<{ ok: boolean; result?: any }>;
}

// ── Subscriber Management (KV) ──────────────────────────
export async function getSubscribers(cache: KVNamespace): Promise<number[]> {
  try {
    const raw = await cache.get("telegram:subscribers", "json");
    if (Array.isArray(raw)) return raw as number[];
  } catch {}
  return [];
}

export async function addSubscriber(
  cache: KVNamespace,
  chatId: number,
): Promise<void> {
  const subs = await getSubscribers(cache);
  if (!subs.includes(chatId)) {
    subs.push(chatId);
    await cache.put("telegram:subscribers", JSON.stringify(subs));
  }
}

export async function removeSubscriber(
  cache: KVNamespace,
  chatId: number,
): Promise<void> {
  const subs = await getSubscribers(cache);
  const filtered = subs.filter((id) => id !== chatId);
  await cache.put("telegram:subscribers", JSON.stringify(filtered));
}

// ── Ticker Validation ────────────────────────────────────
export function isValidTicker(text: string): boolean {
  return /^[A-Z]{1,5}$/.test(text);
}

// ── Ticker Keyboard ──────────────────────────────────────
const PRESET_TICKERS = [
  "SPY", "QQQ",
  "NVDA", "TSLA",
  "AAPL", "AMZN",
  "META", "MSFT",
  "GOOG", "AMD",
];

export function buildTickerKeyboard() {
  const rows: { text: string; callback_data: string }[][] = [];
  for (let i = 0; i < PRESET_TICKERS.length; i += 2) {
    const row = [{ text: PRESET_TICKERS[i], callback_data: PRESET_TICKERS[i] }];
    if (i + 1 < PRESET_TICKERS.length) {
      row.push({ text: PRESET_TICKERS[i + 1], callback_data: PRESET_TICKERS[i + 1] });
    }
    rows.push(row);
  }
  return { inline_keyboard: rows };
}

// ── Portfolio Size Management (KV) ──────────────────────
export async function getPortfolioSize(
  cache: KVNamespace,
  chatId: number,
): Promise<number> {
  try {
    const raw = await cache.get(`portfolio:${chatId}`);
    if (raw) return parseFloat(raw) || 0;
  } catch {}
  return 0;
}

export async function setPortfolioSize(
  cache: KVNamespace,
  chatId: number,
  size: number,
): Promise<void> {
  await cache.put(`portfolio:${chatId}`, String(size));
}

// ── Escape for MarkdownV2 (simple strings) ───────────────
export function escapeMd(text: string): string {
  return text.replace(/([_*\[\]()~`>#\+\-=|{}.!])/g, "\\$1");
}

// ═══════════════════════════════════════════════════════════
// Paper Trading Position Management (KV)
// ═══════════════════════════════════════════════════════════

import type { PaperPosition, ClosedTrade, PendingSignal } from "./types";

// ── KV Key Prefix ───────────────────────────────────────────
// Bot A uses the original key format (backward compatible).
// Bot B, C, etc. use a namespaced prefix.
function kp(botId: string): string {
  return botId === "A" ? "trade" : `bot:${botId.toLowerCase()}`;
}

// ── Pending Signals (waiting for stock to reach entry) ──────

export async function getPendingTickers(cache: KVNamespace, botId = "A"): Promise<string[]> {
  try {
    const raw = await cache.get(`${kp(botId)}:pending_tickers`, "json");
    if (Array.isArray(raw)) return raw as string[];
  } catch {}
  return [];
}

async function savePendingTickers(cache: KVNamespace, botId: string, tickers: string[]): Promise<void> {
  await cache.put(`${kp(botId)}:pending_tickers`, JSON.stringify(tickers));
}

export async function getPendingSignal(cache: KVNamespace, ticker: string, botId = "A"): Promise<PendingSignal | null> {
  try {
    const raw = await cache.get(`${kp(botId)}:pending:${ticker}`, "json");
    return raw as PendingSignal | null;
  } catch {}
  return null;
}

export async function savePendingSignal(cache: KVNamespace, signal: PendingSignal, botId = "A"): Promise<void> {
  await cache.put(`${kp(botId)}:pending:${signal.ticker}`, JSON.stringify(signal), { expirationTtl: 28800 });
  const tickers = await getPendingTickers(cache, botId);
  if (!tickers.includes(signal.ticker)) {
    tickers.push(signal.ticker);
    await savePendingTickers(cache, botId, tickers);
  }
}

export async function removePendingSignal(cache: KVNamespace, ticker: string, botId = "A"): Promise<void> {
  await cache.delete(`${kp(botId)}:pending:${ticker}`);
  const tickers = await getPendingTickers(cache, botId);
  await savePendingTickers(cache, botId, tickers.filter((t) => t !== ticker));
}

// ── Open Positions ──────────────────────────────────────────

export async function getOpenTickers(cache: KVNamespace, botId = "A"): Promise<string[]> {
  try {
    const raw = await cache.get(`${kp(botId)}:open_tickers`, "json");
    if (Array.isArray(raw)) return raw as string[];
  } catch {}
  return [];
}

async function saveOpenTickers(cache: KVNamespace, botId: string, tickers: string[]): Promise<void> {
  await cache.put(`${kp(botId)}:open_tickers`, JSON.stringify(tickers));
}

export async function getOpenPosition(cache: KVNamespace, ticker: string, botId = "A"): Promise<PaperPosition | null> {
  try {
    const raw = await cache.get(`${kp(botId)}:open:${ticker}`, "json");
    return raw as PaperPosition | null;
  } catch {}
  return null;
}

export async function saveOpenPosition(cache: KVNamespace, pos: PaperPosition, botId = "A"): Promise<void> {
  await cache.put(`${kp(botId)}:open:${pos.ticker}`, JSON.stringify(pos));
  const tickers = await getOpenTickers(cache, botId);
  if (!tickers.includes(pos.ticker)) {
    tickers.push(pos.ticker);
    await saveOpenTickers(cache, botId, tickers);
  }
}

export async function removeOpenPosition(cache: KVNamespace, ticker: string, botId = "A"): Promise<void> {
  await cache.delete(`${kp(botId)}:open:${ticker}`);
  const tickers = await getOpenTickers(cache, botId);
  await saveOpenTickers(cache, botId, tickers.filter(t => t !== ticker));
}

// ── Closed Trades ───────────────────────────────────────────

export async function addClosedTrade(cache: KVNamespace, trade: ClosedTrade, botId = "A"): Promise<void> {
  const trades = await getClosedTrades(cache, 100, botId);
  trades.unshift(trade);
  if (trades.length > 100) trades.length = 100;
  await cache.put(`${kp(botId)}:closed`, JSON.stringify(trades));
}

export async function getClosedTrades(cache: KVNamespace, limit = 100, botId = "A"): Promise<ClosedTrade[]> {
  try {
    const raw = await cache.get(`${kp(botId)}:closed`, "json");
    if (Array.isArray(raw)) return (raw as ClosedTrade[]).slice(0, limit);
  } catch {}
  return [];
}

// ── Cooldown Management ─────────────────────────────────────

export async function setLastExitTime(cache: KVNamespace, ticker: string, botId = "A"): Promise<void> {
  await cache.put(`${kp(botId)}:last_exit:${ticker}`, new Date().toISOString(), { expirationTtl: 7200 });
}

export async function getLastExitTime(cache: KVNamespace, ticker: string, botId = "A"): Promise<Date | null> {
  const val = await cache.get(`${kp(botId)}:last_exit:${ticker}`);
  return val ? new Date(val) : null;
}

// ── Daily P&L Tracking ──────────────────────────────────────

function todayKey(botId: string): string {
  const d = new Date();
  return `${kp(botId)}:daily_pnl:${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export async function getDailyPnl(cache: KVNamespace, botId = "A"): Promise<number> {
  try {
    const raw = await cache.get(todayKey(botId));
    if (raw) return parseFloat(raw) || 0;
  } catch {}
  return 0;
}

export async function addDailyPnl(cache: KVNamespace, pnl: number, botId = "A"): Promise<void> {
  const current = await getDailyPnl(cache, botId);
  await cache.put(todayKey(botId), String(current + pnl), { expirationTtl: 86400 });
}

// ── Daily Trade Count ───────────────────────────────────────

function todayCountKey(botId: string): string {
  const d = new Date();
  return `${kp(botId)}:daily_count:${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export async function getDailyTradeCount(cache: KVNamespace, botId = "A"): Promise<number> {
  try {
    const raw = await cache.get(todayCountKey(botId));
    if (raw) return parseInt(raw, 10) || 0;
  } catch {}
  return 0;
}

export async function incrementDailyTradeCount(cache: KVNamespace, botId = "A"): Promise<void> {
  const current = await getDailyTradeCount(cache, botId);
  await cache.put(todayCountKey(botId), String(current + 1), { expirationTtl: 86400 });
}
