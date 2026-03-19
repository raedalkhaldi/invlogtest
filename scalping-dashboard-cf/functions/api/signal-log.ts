// ═══════════════════════════════════════════════════════════
// GET /api/signal-log — Signal History Reader
//
// Returns all signals evaluated by the trading cron for a
// given date and bot. Used for backtesting analysis.
//
// Query params:
//   date  — YYYY-MM-DD (default: today)
//   botId — A | B | C (default: A)
//   outcome — filter by outcome (optional: QUEUED, SKIPPED_*)
// ═══════════════════════════════════════════════════════════

import type { Env } from "../../src/types";

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { env, request } = context;
  const url = new URL(request.url);

  const botId  = (url.searchParams.get("botId") || "A").toUpperCase();
  const outcome = url.searchParams.get("outcome") ?? null;

  // Default to today ET
  const nowET = new Date(new Date().toLocaleString("en-US", { timeZone: "America/New_York" }));
  const todayET = nowET.toISOString().slice(0, 10);
  const date = url.searchParams.get("date") || todayET;

  const kvKey = `signal:log:${date}:${botId}`;

  try {
    const entries = await env.SCALPING_CACHE.get(kvKey, "json") as object[] | null;
    const all = entries ?? [];

    const filtered = outcome
      ? all.filter((e: any) => e.outcome === outcome)
      : all;

    // Summary stats
    const queued   = all.filter((e: any) => e.outcome === "QUEUED").length;
    const skipped  = all.filter((e: any) => e.outcome?.startsWith("SKIPPED")).length;
    const byOutcome: Record<string, number> = {};
    for (const e of all as any[]) {
      byOutcome[e.outcome] = (byOutcome[e.outcome] ?? 0) + 1;
    }

    return Response.json({
      date,
      bot_id:  botId,
      total:   all.length,
      queued,
      skipped,
      by_outcome: byOutcome,
      signals: filtered,
    });
  } catch (err: any) {
    return Response.json({ error: err.message }, { status: 500 });
  }
};
