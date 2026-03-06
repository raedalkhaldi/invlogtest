// ═══════════════════════════════════════════════════════════
// GET /api/telegram-cron — Auto-Alert Scanner
// Called by external cron (cron-job.org) every 5 minutes
// during market hours. Scans 8 tickers, sends alerts for
// tradeable signals to all subscribers.
// ═══════════════════════════════════════════════════════════

import type { Env } from "../../src/types";
import { formatAlertCompact } from "../../src/telegram-formatter";
import { tgSend, getSubscribers, getPortfolioSize } from "../../src/telegram-helpers";
import { isMarketOpen } from "../../src/alpaca";
import { getBotConfig, isInActiveHours } from "../../src/bot-config";

const ALERT_TICKERS = [
  "SPY", "QQQ", "NVDA", "TSLA",
  "AAPL", "AMZN", "META", "MSFT",
];

const ALERT_SENT_TTL = 900; // 15 min — prevents duplicate alerts

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { env, request } = context;

  // ── Auth ───────────────────────────────────────────────
  const url = new URL(request.url);
  const secretParam = url.searchParams.get("secret");
  const authHeader = request.headers.get("Authorization");
  const bearerToken = authHeader?.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;
  const providedSecret = bearerToken || secretParam;

  if (!env.CRON_SECRET || providedSecret !== env.CRON_SECRET) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const token = env.TELEGRAM_BOT_TOKEN;
  if (!token) {
    return Response.json({ error: "No bot token" }, { status: 500 });
  }

  // ── Market + Active Hours check ────────────────────────
  const alpacaKey    = env.ALPACA_API_KEY;
  const alpacaSecret = env.ALPACA_API_SECRET;
  const auth = { key: alpacaKey, secret: alpacaSecret };

  const marketOpen = await isMarketOpen(auth);
  if (!marketOpen) {
    return Response.json({ message: "Market closed — no alerts sent", alerts_sent: 0 });
  }

  const cfg = await getBotConfig(env.SCALPING_CACHE, "A");
  if (!isInActiveHours(cfg)) {
    return Response.json({ message: `Outside active hours (${cfg.activeHoursStart}–${cfg.activeHoursEnd} ET) — no alerts sent`, alerts_sent: 0 });
  }

  // ── Subscribers ────────────────────────────────────────
  const subscribers = await getSubscribers(env.SCALPING_CACHE);
  if (subscribers.length === 0) {
    return Response.json({ message: "No subscribers", alerts_sent: 0 });
  }

  // ── Fetch all tickers in parallel (force = live price) ─
  const apiBase = new URL(request.url).origin;

  const results = await Promise.allSettled(
    ALERT_TICKERS.map(async (ticker) => {
      try {
        const resp = await fetch(`${apiBase}/api/fetch`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ticker, force: true }),
        });
        if (!resp.ok) return null;
        return (await resp.json()) as any;
      } catch {
        return null;
      }
    }),
  );

  // ── Filter tradeable + dedup + send alerts ─────────────
  let alertsSent = 0;
  const errors: string[] = [];

  for (let i = 0; i < ALERT_TICKERS.length; i++) {
    const ticker = ALERT_TICKERS[i];
    const result = results[i];
    if (result.status !== "fulfilled" || !result.value) continue;

    const data = result.value;
    const signal = data.scalp_signal;
    if (!signal || !signal.tradeable) continue;

    // Build fingerprint for dedup
    const fingerprint = `${signal.direction}|${signal.entry}|${signal.confluence_score}`;
    const kvKey = `alert:sent:${ticker}`;

    try {
      const existing = await env.SCALPING_CACHE.get(kvKey);
      if (existing === fingerprint) continue; // already sent
    } catch {}

    // Send alert to all subscribers (per-subscriber portfolio sizing)
    for (const chatId of subscribers) {
      try {
        const portfolioSize = await getPortfolioSize(env.SCALPING_CACHE, chatId);
        const alertText = formatAlertCompact(data, portfolioSize);
        await tgSend(token, "sendMessage", {
          chat_id: chatId,
          text: alertText,
          parse_mode: "MarkdownV2",
          reply_markup: {
            inline_keyboard: [
              [
                {
                  text: "\u{1F4CA} التقرير الكامل",
                  callback_data: `report:${ticker}`,
                },
              ],
            ],
          },
        });
      } catch (err: any) {
        errors.push(`${ticker}→${chatId}: ${err.message}`);
      }
    }

    // Mark as sent (15 min TTL)
    try {
      await env.SCALPING_CACHE.put(kvKey, fingerprint, {
        expirationTtl: ALERT_SENT_TTL,
      });
    } catch {}

    alertsSent++;
  }

  return Response.json({
    message: "Cron completed",
    tickers_scanned: ALERT_TICKERS.length,
    alerts_sent: alertsSent,
    subscribers: subscribers.length,
    errors: errors.length > 0 ? errors : undefined,
  });
};
