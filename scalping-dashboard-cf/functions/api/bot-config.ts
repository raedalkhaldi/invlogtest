// ═══════════════════════════════════════════════════════════
// GET  /api/bot-config?botId=A  — read config
// POST /api/bot-config          — save config (body = BotConfig JSON)
// ═══════════════════════════════════════════════════════════

import type { Env, BotConfig } from "../../src/types";
import { getBotConfig, setBotConfig, DEFAULT_BOT_CONFIG } from "../../src/bot-config";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json",
};

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url);
  const botId = url.searchParams.get("botId") || "A";
  const cfg = await getBotConfig(context.env.SCALPING_CACHE, botId);
  return Response.json(cfg, { headers: CORS });
};

export const onRequestPost: PagesFunction<Env> = async (context) => {
  try {
    const body = await context.request.json() as Partial<BotConfig>;

    // Validate required fields
    if (!body || typeof body !== "object") {
      return Response.json({ error: "Invalid body" }, { status: 400, headers: CORS });
    }

    const botId = (body.botId as string) || "A";
    const existing = await getBotConfig(context.env.SCALPING_CACHE, botId);

    // Merge — only update provided fields, keep existing for the rest
    const updated: BotConfig = { ...existing, ...body, botId };

    // Basic validations
    if (updated.dailyLossLimit > 0) updated.dailyLossLimit = -Math.abs(updated.dailyLossLimit);
    if (updated.riskPctGradeA > 10) updated.riskPctGradeA = 10;
    if (updated.riskPctGradeB > 10) updated.riskPctGradeB = 10;
    if (updated.maxContracts < 1) updated.maxContracts = 1;
    if (updated.maxOpenPositions < 1) updated.maxOpenPositions = 1;

    await setBotConfig(context.env.SCALPING_CACHE, updated);
    return Response.json({ ok: true, config: updated }, { headers: CORS });
  } catch (err: any) {
    return Response.json({ error: err.message }, { status: 500, headers: CORS });
  }
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
};
