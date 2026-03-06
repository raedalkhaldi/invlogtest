// ═══════════════════════════════════════════════════════════
// GET /api/paper-trades?botId=A  — Returns open positions + closed trades
// Supports multi-bot: ?botId=A (default), B, or C
// ═══════════════════════════════════════════════════════════

import type { Env } from "../../src/types";
import {
  getOpenTickers,
  getOpenPosition,
  getClosedTrades,
  getDailyPnl,
  getDailyTradeCount,
} from "../../src/telegram-helpers";
import { getBotConfig } from "../../src/bot-config";

const CORS = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const cache = context.env.SCALPING_CACHE;
  const url = new URL(context.request.url);
  const botId = (url.searchParams.get("botId") || "A").toUpperCase();

  const cfg = await getBotConfig(cache, botId);

  const openTickers = await getOpenTickers(cache, botId);
  const openPositions = [];
  for (const ticker of openTickers) {
    const pos = await getOpenPosition(cache, ticker, botId);
    if (pos) openPositions.push(pos);
  }

  const closedTrades = await getClosedTrades(cache, 50, botId);
  const dailyPnl = await getDailyPnl(cache, botId);
  const dailyTradeCount = await getDailyTradeCount(cache, botId);

  return Response.json({
    bot_id: botId,
    bot_enabled: cfg.enabled,
    bot_strategy: cfg.strategy,
    daily_pnl: dailyPnl,
    daily_trade_count: dailyTradeCount,
    open_positions: openPositions,
    closed_trades: closedTrades,
  }, { headers: CORS });
};
