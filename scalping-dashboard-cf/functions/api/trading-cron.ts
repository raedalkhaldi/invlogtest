// ═══════════════════════════════════════════════════════════
// GET /api/trading-cron — Paper Trading Bot (Bot A)
// Called by external cron (cron-job.org) every 5 minutes.
// All behaviour driven by BotConfig stored in KV.
//
// 3-Phase Flow:
//   Phase 1 — EXIT: Close open options when STOCK hits stock_target
//              (or force-close if past forceCloseTime)
//   Phase 2 — ENTRY TRIGGER: Buy option when STOCK hits stock_entry
//   Phase 3 — NEW SIGNALS: Queue fresh pending signals for empty tickers
// ═══════════════════════════════════════════════════════════

import type { Env, PaperPosition, ClosedTrade, PendingSignal, TickerResult } from "../../src/types";
import { computeSizing } from "../../src/sizing";
import { getBotConfig, isInActiveHours, isPastForceCloseTime } from "../../src/bot-config";
import {
  buildOccSymbol,
  placeOptionOrder,
  closePosition,
  getPositions,
  getOrder,
  getStockPrice,
  isMarketOpen,
} from "../../src/alpaca";
import {
  tgSend,
  getSubscribers,
  getOpenTickers,
  getOpenPosition,
  saveOpenPosition,
  removeOpenPosition,
  addClosedTrade,
  getPendingTickers,
  getPendingSignal,
  savePendingSignal,
  removePendingSignal,
  escapeMd,
  setLastExitTime,
  getLastExitTime,
  getDailyPnl,
  addDailyPnl,
  getDailyTradeCount,
  incrementDailyTradeCount,
} from "../../src/telegram-helpers";

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { env, request } = context;
  const url = new URL(request.url);
  const log: string[] = [];

  // ── Auth ───────────────────────────────────────────────
  const secretParam = url.searchParams.get("secret");
  const authHeader = request.headers.get("Authorization");
  const bearerToken = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : null;
  const providedSecret = bearerToken || secretParam;
  if (!env.CRON_SECRET || providedSecret !== env.CRON_SECRET) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  // ── Bot ID ─────────────────────────────────────────────
  // Supports ?botId=A|B|C  (default: A)
  const botId = (url.searchParams.get("botId") || "A").toUpperCase();

  // ── Load config ────────────────────────────────────────
  const cfg = await getBotConfig(env.SCALPING_CACHE, botId);

  if (!cfg.enabled) {
    return Response.json({ message: `Bot ${botId} is disabled`, trades: 0 });
  }

  // ── Alpaca credentials — per-bot, falls back to Bot A keys ──
  const alpacaKey    = (env as any)[`ALPACA_API_KEY_${botId}`]    || env.ALPACA_API_KEY;
  const alpacaSecret = (env as any)[`ALPACA_API_SECRET_${botId}`] || env.ALPACA_API_SECRET;
  const auth = { key: alpacaKey, secret: alpacaSecret };

  // ── Market check ──────────────────────────────────────
  const marketOpen = await isMarketOpen(auth);
  if (!marketOpen) {
    return Response.json({ message: "Market closed", trades: 0 });
  }

  // ── Active hours check ────────────────────────────────
  if (!isInActiveHours(cfg)) {
    return Response.json({ message: `Bot ${botId}: outside active hours (${cfg.activeHoursStart}–${cfg.activeHoursEnd} ET)`, trades: 0 });
  }

  const token = env.TELEGRAM_BOT_TOKEN;
  const cache = env.SCALPING_CACHE;
  const apiBase = url.origin;
  let entriesOpened = 0;
  let exitsClosed = 0;
  const now = new Date();
  const forceClose = isPastForceCloseTime(cfg);

  // ═══════════════════════════════════════════════════════
  // PHASE 1: Exit open positions
  //   a) Force-close if past forceCloseTime
  //   b) Close if stock hits stock_target
  // ═══════════════════════════════════════════════════════

  const openTickers = await getOpenTickers(cache, botId);
  let alpacaPositions: Awaited<ReturnType<typeof getPositions>> = [];
  try {
    alpacaPositions = await getPositions(auth);
  } catch (err: any) {
    log.push(`Failed to get Alpaca positions: ${err.message}`);
  }

  for (const ticker of openTickers) {
    const pos = await getOpenPosition(cache, ticker, botId);
    if (!pos) continue;

    const alpPos = alpacaPositions.find(
      (p) => p.symbol.trim() === pos.occ_symbol.trim(),
    );

    if (!alpPos) {
      // Position gone from Alpaca (expired / manually closed).
      // Remove from KV FIRST — acts as a lock against concurrent cron runs.
      await removeOpenPosition(cache, ticker, botId);
      const closedTrade: ClosedTrade = {
        ...pos,
        exit_premium: pos.entry_premium,
        exit_time: now.toISOString(),
        pnl_dollars: 0,
        pnl_pct: 0,
        result: "EXPIRED",
      };
      await addClosedTrade(cache, closedTrade, botId);
      await setLastExitTime(cache, ticker, botId);
      await addDailyPnl(cache, 0, botId);
      log.push(`${ticker}: Position gone from Alpaca — marked EXPIRED`);
      exitsClosed++;
      continue;
    }

    // ── Force close if past deadline ─────────────────
    if (forceClose) {
      // Remove from KV FIRST — prevents double-close from concurrent cron runs
      await removeOpenPosition(cache, ticker, botId);
      try {
        const closeOrder = await closePosition(auth, pos.occ_symbol.trim());
        await new Promise((r) => setTimeout(r, 2000));
        let exitPremium = parseFloat(alpPos.current_price);
        try {
          const filled = await getOrder(auth, closeOrder.id);
          if (filled.filled_avg_price && parseFloat(filled.filled_avg_price) > 0) {
            exitPremium = parseFloat(filled.filled_avg_price);
          }
        } catch {}
        const pnl = (exitPremium - pos.entry_premium) * pos.contracts * 100;
        const pnlPct = ((exitPremium - pos.entry_premium) / pos.entry_premium) * 100;
        const result: ClosedTrade["result"] = exitPremium > pos.entry_premium ? "WIN" : "LOSS";
        const closedTrade: ClosedTrade = {
          ...pos,
          exit_premium: round2(exitPremium),
          exit_time: now.toISOString(),
          pnl_dollars: round2(pnl),
          pnl_pct: round2(pnlPct),
          result,
        };
        await addClosedTrade(cache, closedTrade, botId);
        await setLastExitTime(cache, ticker, botId);
        await addDailyPnl(cache, pnl, botId);
        const pnlNote = pnl >= 0 ? `+$${pnl.toFixed(0)}` : `-$${Math.abs(pnl).toFixed(0)}`;
        log.push(`${ticker}: FORCE CLOSE (past ${cfg.forceCloseTime} ET) → ${result} ${pnlNote}`);
        exitsClosed++;
        await notifyAll(cache, token, formatExitMsg(closedTrade));
      } catch (err: any) {
        // If Alpaca close failed, restore the position record
        await saveOpenPosition(cache, pos, botId);
        log.push(`${ticker}: Force close FAILED — restored position — ${err.message}`);
      }
      continue;
    }

    // ── Determine exit trigger (stock price vs option premium) ──
    const currentOptionPrice = parseFloat(alpPos.current_price);
    const useOptionPremiumExit = cfg.exitTrigger === "option_premium";

    let targetHit = false;
    let exitReason = "";

    if (useOptionPremiumExit) {
      // Exit when live option price reaches target_premium stored at entry
      targetHit = currentOptionPrice >= pos.target_premium;
      exitReason = `OPTION PREMIUM TARGET HIT ($${currentOptionPrice.toFixed(2)} ≥ $${pos.target_premium.toFixed(2)})`;
      if (!targetHit) {
        const pctToTarget = ((pos.target_premium - currentOptionPrice) / pos.entry_premium * 100).toFixed(0);
        log.push(`${ticker}: Holding — option $${currentOptionPrice.toFixed(2)} (target $${pos.target_premium.toFixed(2)}, +${pctToTarget}% to go)`);
      }
    } else {
      // Original: exit when stock price hits stock_target
      const stockPrice = await getStockPrice(auth, ticker);
      if (stockPrice == null) {
        log.push(`${ticker}: Could not fetch stock price — skip exit check`);
        continue;
      }
      targetHit =
        pos.contract_type === "CALL"
          ? stockPrice >= pos.stock_target
          : stockPrice <= pos.stock_target;
      exitReason = `STOCK TARGET HIT ($${stockPrice.toFixed(2)} vs target $${pos.stock_target.toFixed(2)})`;
      if (!targetHit) {
        log.push(`${ticker}: Holding — stock $${stockPrice.toFixed(2)} (target $${pos.stock_target.toFixed(2)}) option $${currentOptionPrice.toFixed(2)}`);
      }
    }

    if (targetHit) {
      // Remove from KV FIRST — prevents double-close from concurrent cron runs
      await removeOpenPosition(cache, ticker, botId);
      try {
        const closeOrder = await closePosition(auth, pos.occ_symbol.trim());
        await new Promise((r) => setTimeout(r, 2000));
        let exitPremium = currentOptionPrice;
        try {
          const filled = await getOrder(auth, closeOrder.id);
          if (filled.filled_avg_price && parseFloat(filled.filled_avg_price) > 0) {
            exitPremium = parseFloat(filled.filled_avg_price);
          }
        } catch {}
        const pnl = (exitPremium - pos.entry_premium) * pos.contracts * 100;
        const pnlPct = ((exitPremium - pos.entry_premium) / pos.entry_premium) * 100;
        const result: ClosedTrade["result"] = exitPremium > pos.entry_premium ? "WIN" : "LOSS";
        const closedTrade: ClosedTrade = {
          ...pos,
          exit_premium: round2(exitPremium),
          exit_time: now.toISOString(),
          pnl_dollars: round2(pnl),
          pnl_pct: round2(pnlPct),
          result,
        };
        await addClosedTrade(cache, closedTrade, botId);
        await setLastExitTime(cache, ticker, botId);
        await addDailyPnl(cache, pnl, botId);
        const pnlNote = pnl >= 0 ? `+$${pnl.toFixed(0)}` : `-$${Math.abs(pnl).toFixed(0)}`;
        log.push(`${ticker}: ${exitReason} — option @ $${exitPremium.toFixed(2)} → ${result} ${pnlNote}`);
        exitsClosed++;
        await notifyAll(cache, token, formatExitMsg(closedTrade));
      } catch (err: any) {
        // If Alpaca close failed, restore the position record
        await saveOpenPosition(cache, pos, botId);
        log.push(`${ticker}: Failed to close on target — restored position — ${err.message}`);
      }
      continue;
    }
  }

  // ═══════════════════════════════════════════════════════
  // GUARD: Skip entries if force-close time passed
  // ═══════════════════════════════════════════════════════
  if (forceClose) {
    log.push(`Past ${cfg.forceCloseTime} ET — no new entries`);
    return Response.json({ message: "Trading cron completed (force close time)", entries_opened: entriesOpened, exits_closed: exitsClosed, log });
  }

  // ═══════════════════════════════════════════════════════
  // GUARD: Daily loss limit
  // ═══════════════════════════════════════════════════════
  const dailyPnl = await getDailyPnl(cache, botId);
  if (dailyPnl <= cfg.dailyLossLimit) {
    log.push(`Daily loss limit hit ($${dailyPnl.toFixed(0)} ≤ $${cfg.dailyLossLimit}) — no new entries`);
    return Response.json({ message: "Daily loss limit hit", entries_opened: entriesOpened, exits_closed: exitsClosed, daily_pnl: dailyPnl, log });
  }

  // ═══════════════════════════════════════════════════════
  // GUARD: Daily trade count
  // ═══════════════════════════════════════════════════════
  const dailyCount = await getDailyTradeCount(cache, botId);
  if (dailyCount >= cfg.maxTradesPerDay) {
    log.push(`Max trades per day reached (${dailyCount}/${cfg.maxTradesPerDay}) — no new entries`);
    return Response.json({ message: "Max trades per day reached", entries_opened: entriesOpened, exits_closed: exitsClosed, log });
  }

  // ═══════════════════════════════════════════════════════
  // GUARD: Max open positions
  // ═══════════════════════════════════════════════════════
  const refreshedOpenTickers = await getOpenTickers(cache, botId);
  if (refreshedOpenTickers.length >= cfg.maxOpenPositions) {
    log.push(`Max open positions reached (${refreshedOpenTickers.length}/${cfg.maxOpenPositions}) — no new entries`);
    return Response.json({ message: "Max open positions reached", entries_opened: entriesOpened, exits_closed: exitsClosed, log });
  }

  // ═══════════════════════════════════════════════════════
  // PHASE 2: Trigger pending entries when STOCK hits stock_entry
  // ═══════════════════════════════════════════════════════

  const pendingTickers = await getPendingTickers(cache, botId);

  for (const ticker of pendingTickers) {
    if (refreshedOpenTickers.includes(ticker)) {
      await removePendingSignal(cache, ticker, botId);
      log.push(`${ticker}: Already in position — removed pending signal`);
      continue;
    }

    const pending = await getPendingSignal(cache, ticker, botId);
    if (!pending) continue;

    if (now > new Date(pending.expires_at)) {
      await removePendingSignal(cache, ticker, botId);
      log.push(`${ticker}: Pending signal expired — removed`);
      continue;
    }

    // Cooldown check
    const lastExit = await getLastExitTime(cache, ticker, botId);
    if (lastExit) {
      const minutesSince = (now.getTime() - lastExit.getTime()) / 60000;
      if (minutesSince < cfg.cooldownMinutes) {
        log.push(`${ticker}: Cooldown active (${(cfg.cooldownMinutes - minutesSince).toFixed(0)}m left) — skip`);
        continue;
      }
    }

    // Fetch live stock price
    const stockPrice = await getStockPrice(auth, ticker);
    if (stockPrice == null) {
      log.push(`${ticker}: Could not fetch stock price — skip`);
      continue;
    }

    const entryTriggered =
      pending.direction === "LONG"
        ? stockPrice >= pending.stock_entry
        : stockPrice <= pending.stock_entry;

    if (!entryTriggered) {
      const gap = pending.direction === "LONG"
        ? (pending.stock_entry - stockPrice).toFixed(2)
        : (stockPrice - pending.stock_entry).toFixed(2);
      log.push(`${ticker}: Pending ${pending.direction} — stock $${stockPrice.toFixed(2)}, waiting for $${pending.stock_entry.toFixed(2)} (gap $${gap})`);
      continue;
    }

    log.push(`${ticker}: ENTRY TRIGGERED — stock $${stockPrice.toFixed(2)} hit entry $${pending.stock_entry.toFixed(2)}`);

    try {
      const resp = await fetch(`${apiBase}/api/fetch`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ticker, force: true }),
      });
      if (!resp.ok) { log.push(`${ticker}: Fetch failed — skip entry`); continue; }

      const freshData = await resp.json() as TickerResult;
      const opt = freshData.options_signal;
      const freshSignal = freshData.scalp_signal;

      if (!opt || opt.contract_type === "NONE" || opt.grade === "C") {
        log.push(`${ticker}: Fresh option not tradeable (grade ${opt?.grade ?? "none"}) — skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      // Apply config grade filter
      if (cfg.minGrade === "A" && opt.grade !== "A") {
        log.push(`${ticker}: Grade ${opt.grade} below config minimum (A) — skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      // Apply config confluence filter
      if (freshSignal && freshSignal.confluence_score < cfg.minConfluenceScore) {
        log.push(`${ticker}: Confluence ${freshSignal.confluence_score} below minimum ${cfg.minConfluenceScore} — skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      // Direction still valid?
      if (!freshSignal?.tradeable || freshSignal.direction !== pending.direction) {
        log.push(`${ticker}: Scalp direction changed (was ${pending.direction}) — skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      const expectedContract = pending.direction === "LONG" ? "CALL" : "PUT";
      if (opt.contract_type !== expectedContract) {
        log.push(`${ticker}: Contract mismatch — skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      // Strike-cleared check at entry time (catches stale pending signals)
      const strikeCleared =
        opt.contract_type === "CALL"
          ? pending.stock_target > opt.strike
          : pending.stock_target < opt.strike;
      if (!strikeCleared) {
        log.push(`${ticker}: Pending target $${pending.stock_target} doesn't clear ${opt.contract_type} strike $${opt.strike} — stale signal, skip`);
        await removePendingSignal(cache, ticker, botId);
        continue;
      }

      const sizing = computeSizing(cfg.portfolioSize, opt, freshData.scalp_signal, cfg);
      if (!sizing || sizing.contracts < 1) { log.push(`${ticker}: Sizing = 0 contracts — skip`); continue; }

      const occSymbol = buildOccSymbol(ticker, opt.expiration, opt.contract_type, opt.strike);
      const order = await placeOptionOrder(auth, occSymbol, sizing.contracts, "buy");

      let realEntry = opt.entry_premium;
      try {
        await new Promise((r) => setTimeout(r, 2000));
        const filled = await getOrder(auth, order.id);
        if (filled.filled_avg_price && parseFloat(filled.filled_avg_price) > 0) {
          realEntry = parseFloat(filled.filled_avg_price);
        }
      } catch {}

      const pos: PaperPosition = {
        ticker,
        occ_symbol: occSymbol,
        contract_type: opt.contract_type,
        strike: opt.strike,
        expiration: opt.expiration,
        contracts: sizing.contracts,
        entry_premium: realEntry,
        target_premium: opt.target_premium,
        stop_premium: 0,
        stock_target: pending.stock_target,
        entry_time: now.toISOString(),
        signal_grade: opt.grade,
        confidence_tier: sizing.confidence_tier,
        alpaca_order_id: order.id,
      };

      await saveOpenPosition(cache, pos, botId);
      await removePendingSignal(cache, ticker, botId);
      await incrementDailyTradeCount(cache, botId);
      entriesOpened++;
      log.push(`${ticker}: OPENED ${sizing.contracts}x ${opt.contract_type} $${fmtStrike(opt.strike)} @ $${realEntry.toFixed(2)} | stock target $${pending.stock_target.toFixed(2)}`);
      await notifyAll(cache, token, formatEntryMsg(pos, sizing, pending.stock_target));
    } catch (err: any) {
      log.push(`${ticker}: Order FAILED — ${err.message}`);
    }
  }

  // ═══════════════════════════════════════════════════════
  // PHASE 3: Queue new pending signals for empty tickers
  // ═══════════════════════════════════════════════════════

  const afterOpenTickers = await getOpenTickers(cache, botId);
  const afterPendingTickers = await getPendingTickers(cache, botId);
  const currentCount = await getDailyTradeCount(cache, botId);

  if (currentCount >= cfg.maxTradesPerDay) {
    log.push(`Max trades per day reached after entries — skip phase 3`);
    return Response.json({ message: "Trading cron completed", entries_opened: entriesOpened, exits_closed: exitsClosed, daily_pnl: dailyPnl, log });
  }

  const fetchResults = await Promise.allSettled(
    cfg.tickers.map(async (ticker) => {
      if (afterOpenTickers.includes(ticker) || afterPendingTickers.includes(ticker)) {
        return { ticker, skip: true, data: null };
      }
      try {
        const resp = await fetch(`${apiBase}/api/fetch`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ticker, force: true }),
        });
        if (!resp.ok) return { ticker, skip: false, data: null };
        return { ticker, skip: false, data: await resp.json() as TickerResult };
      } catch {
        return { ticker, skip: false, data: null };
      }
    }),
  );

  for (const result of fetchResults) {
    if (result.status !== "fulfilled" || !result.value) continue;
    const { ticker, skip, data } = result.value;
    if (skip || !data) continue;

    const signal = data.scalp_signal;
    const opt = data.options_signal;

    if (!signal?.tradeable || !opt || opt.contract_type === "NONE") continue;

    // Apply config filters
    if (cfg.minGrade === "A" && opt.grade !== "A") continue;
    if (opt.grade !== "A" && opt.grade !== "B") continue;
    if (signal.confluence_score < cfg.minConfluenceScore) {
      log.push(`${ticker}: Confluence ${signal.confluence_score} below ${cfg.minConfluenceScore} — skip`);
      continue;
    }

    // Direction / contract guard
    const expectedCt = signal.direction === "LONG" ? "CALL" : "PUT";
    if (opt.contract_type !== expectedCt) {
      log.push(`${ticker}: Contract/direction mismatch — skip`);
      continue;
    }

    // Cooldown check
    const lastExit = await getLastExitTime(cache, ticker, botId);
    if (lastExit) {
      const minutesSince = (now.getTime() - lastExit.getTime()) / 60000;
      if (minutesSince < cfg.cooldownMinutes) {
        log.push(`${ticker}: Cooldown active — skip queuing`);
        continue;
      }
    }

    // Pick stock_target: Grade A uses farther target, Grade B uses nearer
    const stockTarget =
      opt.grade === "A" && signal.target_a != null
        ? signal.target_a
        : signal.target;

    if (!stockTarget || !signal.entry) { log.push(`${ticker}: No valid stock target — skip`); continue; }

    // Direction sanity: target must be on the correct side of entry
    const targetOk =
      signal.direction === "LONG" ? stockTarget > signal.entry : stockTarget < signal.entry;
    if (!targetOk) {
      log.push(`${ticker}: Target $${stockTarget.toFixed(2)} wrong side of entry $${signal.entry.toFixed(2)} — skip`);
      continue;
    }

    // Strike-cleared check: target must put the option IN the money at exit.
    // A CALL is worthless if stock never reaches the strike; same for PUT below strike.
    const strikeCleared =
      opt.contract_type === "CALL"
        ? stockTarget > opt.strike        // stock must go ABOVE strike to profit
        : stockTarget < opt.strike;       // stock must go BELOW strike to profit
    if (!strikeCleared) {
      log.push(`${ticker}: Target $${stockTarget.toFixed(2)} doesn't clear ${opt.contract_type} strike $${opt.strike} — skip (OTM at target)`);
      continue;
    }

    const sizing = computeSizing(cfg.portfolioSize, opt, signal, cfg);
    const tier = sizing?.confidence_tier ?? 2;

    const expiresAt = new Date();
    expiresAt.setUTCHours(19, 50, 0, 0);
    if (expiresAt <= now) expiresAt.setTime(now.getTime() + 5 * 60 * 1000);

    const pending: PendingSignal = {
      ticker,
      direction: signal.direction as "LONG" | "SHORT",
      stock_entry: signal.entry,
      stock_target: stockTarget,
      option_strike: opt.strike,
      option_expiration: opt.expiration,
      contract_type: opt.contract_type,
      signal_grade: opt.grade as "A" | "B",
      confidence_tier: tier,
      created_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
    };

    await savePendingSignal(cache, pending, botId);
    log.push(`${ticker}: PENDING — ${signal.direction} ${opt.grade} entry@$${signal.entry.toFixed(2)} target@$${stockTarget.toFixed(2)}`);
  }

  return Response.json({
    message: "Trading cron completed",
    entries_opened: entriesOpened,
    exits_closed: exitsClosed,
    daily_pnl: dailyPnl,
    daily_trades: await getDailyTradeCount(cache, botId),
    open_positions: (await getOpenTickers(cache, botId)).length,
    pending_signals: (await getPendingTickers(cache, botId)).length,
    log,
  });
};

// ═══════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════

function round2(n: number): number { return Math.round(n * 100) / 100; }
function fmtStrike(s: number): string { return s % 1 === 0 ? s.toFixed(0) : s.toFixed(2); }

function formatEntryMsg(pos: PaperPosition, sizing: { total_cost: number; risk_pct: number }, stockTarget: number): string {
  const esc = escapeMd;
  const emoji = pos.contract_type === "CALL" ? "🟢" : "🔴";
  const typeAr = pos.contract_type === "CALL" ? "شراء كول" : "شراء بوت";
  const lines = [
    `${emoji} *${esc("🤖 بوت تداول — دخول جديد")}*`,
    "",
    `*${esc(pos.ticker)}* ${esc(typeAr)} ${esc(`$${fmtStrike(pos.strike)}`)}`,
    `${esc("العقود:")} ${esc(String(pos.contracts))}  ${esc("التكلفة:")} ${esc(`$${sizing.total_cost.toLocaleString()}`)}`,
    `${esc("دخول الأوبشن:")} ${esc(`$${pos.entry_premium.toFixed(2)}`)}  ${esc("هدف السهم:")} ${esc(`$${stockTarget.toFixed(2)}`)}`,
    `${esc("التقييم:")} ${esc(pos.signal_grade)}  ${esc("الوقف:")} ${esc("بدون")}`,
  ];
  return lines.join("\n");
}

function formatExitMsg(trade: ClosedTrade): string {
  const esc = escapeMd;
  const isWin = trade.result === "WIN";
  const emoji = isWin ? "✅" : trade.result === "EXPIRED" ? "⏰" : "❌";
  const resultAr = isWin ? "ربح" : trade.result === "EXPIRED" ? "انتهاء" : "خسارة";
  const pnlSign = trade.pnl_dollars >= 0 ? "+" : "";
  const lines = [
    `${emoji} *${esc("🤖 بوت تداول — خروج")}*`,
    "",
    `*${esc(trade.ticker)}* ${esc(trade.contract_type)} ${esc(`$${fmtStrike(trade.strike)}`)}`,
    `${esc(resultAr)} ${esc(`${pnlSign}$${trade.pnl_dollars.toFixed(0)}`)} ${esc(`(${pnlSign}${trade.pnl_pct.toFixed(1)}%)`)}`,
    `${esc("الدخول:")} ${esc(`$${trade.entry_premium.toFixed(2)}`)} → ${esc("الخروج:")} ${esc(`$${trade.exit_premium.toFixed(2)}`)}`,
  ];
  return lines.join("\n");
}

async function notifyAll(cache: KVNamespace, token: string, text: string) {
  const subscribers = await getSubscribers(cache);
  for (const chatId of subscribers) {
    try {
      await tgSend(token, "sendMessage", { chat_id: chatId, text, parse_mode: "MarkdownV2" });
    } catch {}
  }
}
