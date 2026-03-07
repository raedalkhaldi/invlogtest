// ═══════════════════════════════════════════════════════════
// Exit Streamer — Real-time position exit monitor
//
// Flow:
//   1. Every 60s: fetch open positions from Cloudflare /api/paper-trades
//   2. Subscribe to Alpaca real-time trade feed for those tickers
//   3. On each trade tick: check if stock_target is hit
//   4. If hit: close the option via Alpaca + notify Cloudflare to record
//
// Supports all 3 bots (A, B, C) — monitors all simultaneously.
// ═══════════════════════════════════════════════════════════

import WebSocket from "ws";
import fetch from "node-fetch";
import { createServer } from "http";

// ── Config (from env vars) ────────────────────────────────
const CF_BASE        = process.env.CF_BASE_URL   || "https://scalping-dashboard.pages.dev";
const CRON_SECRET    = process.env.CRON_SECRET;
const BOT_IDS        = (process.env.BOT_IDS || "A").split(",").map(s => s.trim().toUpperCase());

// Per-bot Alpaca credentials
function alpacaCreds(botId) {
  const key    = process.env[`ALPACA_API_KEY_${botId}`]    || process.env.ALPACA_API_KEY;
  const secret = process.env[`ALPACA_API_SECRET_${botId}`] || process.env.ALPACA_API_SECRET;
  return { key, secret };
}

const ALPACA_PAPER_REST = "https://paper-api.alpaca.markets/v2";
const ALPACA_WS_DATA    = "wss://stream.data.alpaca.markets/v2/iex";

// ── State ─────────────────────────────────────────────────
// Map: ticker → array of open positions (across all bots)
let openPositions = [];   // [{ botId, ticker, occ_symbol, contract_type, stock_target, ... }]
let subscribedTickers = new Set();

let wsData  = null;  // Alpaca market data WebSocket
let wsPing  = null;  // keepalive interval

// ── Logging ───────────────────────────────────────────────
function log(msg) {
  console.log(`[${new Date().toISOString().slice(11, 19)} ET] ${msg}`);
}

// ── Alpaca REST helpers ───────────────────────────────────

async function alpacaGet(botId, path) {
  const { key, secret } = alpacaCreds(botId);
  const resp = await fetch(`${ALPACA_PAPER_REST}${path}`, {
    headers: { "APCA-API-KEY-ID": key, "APCA-API-SECRET-KEY": secret },
  });
  if (!resp.ok) throw new Error(`Alpaca GET ${path} → ${resp.status}`);
  return resp.json();
}

async function alpacaDelete(botId, path) {
  const { key, secret } = alpacaCreds(botId);
  const resp = await fetch(`${ALPACA_PAPER_REST}${path}`, {
    method: "DELETE",
    headers: { "APCA-API-KEY-ID": key, "APCA-API-SECRET-KEY": secret },
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Alpaca DELETE ${path} → ${resp.status}: ${txt.slice(0, 100)}`);
  }
  return resp.json().catch(() => ({}));
}

// Close an option position by OCC symbol
async function closeAlpacaPosition(botId, occSymbol) {
  // Alpaca expects the OCC symbol URL-encoded
  const encoded = encodeURIComponent(occSymbol.trim());
  return alpacaDelete(botId, `/positions/${encoded}`);
}

// ── Cloudflare API helpers ────────────────────────────────

// Fetch all open positions across all bots
async function fetchOpenPositions() {
  const all = [];
  for (const botId of BOT_IDS) {
    try {
      const resp = await fetch(`${CF_BASE}/api/paper-trades?botId=${botId}`);
      if (!resp.ok) continue;
      const data = await resp.json();
      for (const pos of (data.open_positions || [])) {
        all.push({ ...pos, botId });
      }
    } catch (err) {
      log(`[Bot ${botId}] Failed to fetch positions: ${err.message}`);
    }
  }
  return all;
}

// Tell Cloudflare cron to run (it will handle the exit recording via KV)
// We call it with force=exit to let it detect the position is gone from Alpaca
// (after we close it, Alpaca removes it, next cron marks it EXPIRED/closed)
// Actually we DON'T notify — we let the 5-min cron pick it up as "gone from Alpaca".
// The streamer only does the Alpaca close — the cron does KV cleanup.
// This keeps the streamer simple and stateless.

// ── Position sync ─────────────────────────────────────────

async function syncPositions() {
  try {
    const fresh = await fetchOpenPositions();
    openPositions = fresh;

    const tickers = new Set(fresh.map(p => p.ticker));

    // Re-subscribe if ticker set changed
    const newTickers = [...tickers].filter(t => !subscribedTickers.has(t));
    const removedTickers = [...subscribedTickers].filter(t => !tickers.has(t));

    if (newTickers.length > 0 || removedTickers.length > 0) {
      log(`Positions: ${fresh.length} open across bots [${BOT_IDS.join(",")}]`);
      if (newTickers.length) log(`  ↳ Subscribing to: ${newTickers.join(", ")}`);
      if (removedTickers.length) log(`  ↳ Unsubscribing:  ${removedTickers.join(", ")}`);
      subscribedTickers = tickers;
      updateSubscriptions();
    }
  } catch (err) {
    log(`syncPositions error: ${err.message}`);
  }
}

// ── Alpaca WebSocket ──────────────────────────────────────

function connectAlpacaStream() {
  // Use Bot A credentials for market data (IEX data doesn't need per-bot auth)
  const { key, secret } = alpacaCreds("A");

  wsData = new WebSocket(ALPACA_WS_DATA);

  wsData.on("open", () => {
    log("Alpaca data stream connected");
    // Authenticate
    wsData.send(JSON.stringify({ action: "auth", key, secret }));
  });

  wsData.on("message", async (raw) => {
    let msgs;
    try { msgs = JSON.parse(raw); } catch { return; }
    if (!Array.isArray(msgs)) msgs = [msgs];

    for (const msg of msgs) {
      // Auth success
      if (msg.T === "success" && msg.msg === "authenticated") {
        log("Alpaca stream authenticated ✓");
        updateSubscriptions();
        continue;
      }

      // Connection established
      if (msg.T === "success" && msg.msg === "connected") continue;

      // Error
      if (msg.T === "error") {
        log(`Alpaca stream error: ${msg.msg} (${msg.code})`);
        continue;
      }

      // Trade tick — this is what we care about
      if (msg.T === "t") {
        await handleTrade(msg.S, msg.p); // symbol, price
      }
    }
  });

  wsData.on("close", (code, reason) => {
    log(`Alpaca data stream closed (${code}): ${reason} — reconnecting in 5s`);
    clearInterval(wsPing);
    setTimeout(connectAlpacaStream, 5000);
  });

  wsData.on("error", (err) => {
    log(`Alpaca data stream error: ${err.message}`);
  });

  // Keepalive ping every 20s
  wsPing = setInterval(() => {
    if (wsData?.readyState === WebSocket.OPEN) {
      wsData.ping();
    }
  }, 20000);
}

function updateSubscriptions() {
  if (!wsData || wsData.readyState !== WebSocket.OPEN) return;

  const tickers = [...subscribedTickers];
  if (tickers.length === 0) {
    // Unsubscribe all by subscribing to nothing
    wsData.send(JSON.stringify({ action: "unsubscribe", trades: ["*"] }));
    return;
  }

  log(`Subscribing to trades: ${tickers.join(", ")}`);
  wsData.send(JSON.stringify({
    action: "subscribe",
    trades: tickers,
  }));
}

// ── Core exit logic ───────────────────────────────────────

// Track positions we're currently closing (avoid double-close)
const closing = new Set(); // "botId:occSymbol"

// Shared close helper — used by both stock-price and premium triggers
async function closePosition(pos, reason) {
  const key = `${pos.botId}:${pos.occ_symbol}`;
  if (closing.has(key)) return; // already being closed
  closing.add(key);

  log(`🎯 ${reason} — Bot ${pos.botId} ${pos.ticker} ${pos.contract_type} $${pos.strike}`);

  try {
    await closeAlpacaPosition(pos.botId, pos.occ_symbol);
    log(`✅ Closed ${pos.occ_symbol} on Alpaca (Bot ${pos.botId})`);

    // Remove from local state so we don't try again
    openPositions = openPositions.filter(
      p => !(p.occ_symbol === pos.occ_symbol && p.botId === pos.botId)
    );
    subscribedTickers = new Set(openPositions.map(p => p.ticker));
    updateSubscriptions();
  } catch (err) {
    log(`❌ Failed to close ${pos.occ_symbol}: ${err.message}`);
    closing.delete(key); // allow retry on next tick
  }
}

// ── Stock-price exit (WebSocket, sub-second) ──────────────

async function handleTrade(ticker, price) {
  for (const pos of openPositions) {
    if (pos.ticker !== ticker) continue;

    const targetHit = pos.contract_type === "CALL"
      ? price >= pos.stock_target
      : price <= pos.stock_target;

    if (!targetHit) continue;

    await closePosition(
      pos,
      `STOCK TARGET HIT: ${ticker} @ $${price.toFixed(2)} (target $${pos.stock_target.toFixed(2)})`
    );
  }
}

// ── Option-premium exit (polled every 60s via Alpaca REST) ─

async function checkOptionPremiums() {
  if (openPositions.length === 0) return;

  for (const botId of BOT_IDS) {
    const botPositions = openPositions.filter(p => p.botId === botId);
    if (botPositions.length === 0) continue;

    let alpacaPositions;
    try {
      alpacaPositions = await alpacaGet(botId, "/positions");
    } catch (err) {
      log(`[Bot ${botId}] Alpaca positions fetch failed: ${err.message}`);
      continue;
    }

    for (const pos of botPositions) {
      if (!pos.target_premium || pos.target_premium <= 0) continue;

      const alpPos = alpacaPositions.find(
        p => p.symbol.trim() === pos.occ_symbol.trim()
      );
      if (!alpPos) continue;

      const currentPrice = parseFloat(alpPos.current_price);
      const returnPct = ((currentPrice - pos.entry_premium) / pos.entry_premium * 100).toFixed(0);

      if (currentPrice >= pos.target_premium) {
        await closePosition(
          pos,
          `PREMIUM TARGET HIT: ${pos.ticker} option $${currentPrice.toFixed(2)} ≥ $${pos.target_premium.toFixed(2)} (+${returnPct}%)`
        );
      } else {
        log(`  ${pos.ticker} option @ $${currentPrice.toFixed(2)} / target $${pos.target_premium.toFixed(2)} (${returnPct > 0 ? '+' : ''}${returnPct}%)`);
      }
    }
  }
}

// ── Main ──────────────────────────────────────────────────

async function main() {
  log("═══════════════════════════════════════════");
  log("  Exit Streamer — starting up");
  log(`  Bots: ${BOT_IDS.join(", ")}`);
  log(`  CF:   ${CF_BASE}`);
  log("═══════════════════════════════════════════");

  if (!CRON_SECRET) {
    log("WARNING: CRON_SECRET not set — Cloudflare cron calls will fail auth");
  }

  // Initial position sync
  await syncPositions();

  // Connect to Alpaca real-time stream
  connectAlpacaStream();

  // Sync positions every 60s (picks up new entries)
  // After each sync, check option premiums via Alpaca REST
  setInterval(async () => {
    await syncPositions();
    await checkOptionPremiums();
  }, 60_000);

  // Also run premium check immediately after startup sync
  await checkOptionPremiums();
}

// ── HTTP health check (required for Render free tier) ─────
const PORT = process.env.PORT || 3000;
createServer((req, res) => {
  const status = {
    ok: true,
    uptime: process.uptime().toFixed(0) + "s",
    open_positions: openPositions.length,
    subscribed_tickers: [...subscribedTickers],
    bots: BOT_IDS,
    ws_state: wsData ? ["CONNECTING","OPEN","CLOSING","CLOSED"][wsData.readyState] : "none",
  };
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify(status, null, 2));
}).listen(PORT, () => {
  log(`Health check server on :${PORT}`);
});

main().catch(err => {
  console.error("Fatal:", err);
  process.exit(1);
});
