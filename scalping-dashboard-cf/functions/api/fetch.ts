// ═══════════════════════════════════════════════════════════
// POST /api/fetch — Cloudflare Pages Function
// ═══════════════════════════════════════════════════════════

import type { Env, FetchRequest } from "../../src/types";
import {
  getNearestExpiration,
  getSpotPrice,
  getOptionsChain,
  getHistoricalBars,
} from "../../src/api";
import {
  parseChain,
  computeGammaWalls,
  computeDex,
  computeExpectedMove,
  computeNormalizations,
  buildVolumeProfile,
  confluenceEngine,
  generateSignal,
  generateOptionsSignal,
  buildSupportResistance,
} from "../../src/calculations";

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const { env } = context;
  const apiKey = env.MASSIVE_API_KEY;

  if (!apiKey) {
    return Response.json(
      { error: "MASSIVE_API_KEY not configured" },
      { status: 500 }
    );
  }

  // Parse request body
  let body: FetchRequest;
  try {
    body = await context.request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const ticker = (body.ticker || "").toUpperCase().trim();
  const force = !!body.force;

  if (!ticker || ticker.length > 5) {
    return Response.json({ error: "Invalid ticker" }, { status: 400 });
  }

  // Check KV cache (unless force refresh)
  if (!force) {
    try {
      const cached = await env.SCALPING_CACHE.get(`ticker:${ticker}`, "json");
      if (cached) {
        return Response.json(cached);
      }
    } catch {
      // cache miss or error — continue to fetch
    }
  }

  try {
    // ── Full Pipeline ──────────────────────────────────
    // 1. Spot price
    const spot = await getSpotPrice(ticker, apiKey);

    // 2. Nearest expiration
    const expiration = await getNearestExpiration(ticker, apiKey);

    // 3. Options chain
    const [rawChain, updatedSpot] = await getOptionsChain(
      ticker,
      expiration,
      spot,
      apiKey,
      10
    );

    // 4. Historical bars for volume profile
    const bars = await getHistoricalBars(ticker, apiKey, 5, 10);

    // ── Compute everything ─────────────────────────────
    const [rows, dte] = parseChain(rawChain, updatedSpot, expiration);
    const [walls, totalGex, regime] = computeGammaWalls(rows, updatedSpot);
    const [totalDex, deltaBias] = computeDex(rows);
    const expectedMove = computeExpectedMove(rows, updatedSpot, dte);
    const normalizedRows = computeNormalizations(rows, totalGex);
    const vp = buildVolumeProfile(bars);
    const confluence = confluenceEngine(walls, vp, updatedSpot, deltaBias, regime, expectedMove);
    const signal = generateSignal(
      walls,
      vp,
      updatedSpot,
      totalGex,
      deltaBias,
      expectedMove,
      confluence,
      normalizedRows,
    );
    const srLevels = buildSupportResistance(walls, vp, updatedSpot);
    const optionsSignal = generateOptionsSignal(normalizedRows, signal, updatedSpot);

    const result = {
      ticker,
      timestamp: new Date()
        .toISOString()
        .replace("T", " ")
        .slice(0, 19),
      spot: Math.round(updatedSpot * 100) / 100,
      expiration,
      dte,
      gamma_regime: regime,
      net_gex: totalGex,
      total_dex: totalDex,
      delta_bias: deltaBias,
      expected_move: expectedMove,
      walls,
      volume_profile: {
        poc: vp.poc,
        value_area_high: vp.value_area_high,
        value_area_low: vp.value_area_low,
        hvn_levels: vp.hvn_levels,
        lvn_levels: vp.lvn_levels,
        profile: vp.profile,
      },
      confluence_levels: confluence,
      scalp_signal: signal,
      options_signal: optionsSignal,
      support_resistance: srLevels,
      options_chain: normalizedRows,
      signal_ready: Object.keys(walls).length > 0,
    };

    // Write to KV with 5-min TTL
    try {
      await env.SCALPING_CACHE.put(
        `ticker:${ticker}`,
        JSON.stringify(result),
        { expirationTtl: 300 }
      );
    } catch {
      // Non-critical — cache write failure doesn't block response
    }

    return Response.json(result);
  } catch (e: any) {
    return Response.json(
      { error: e.message || "Unknown error" },
      { status: 500 }
    );
  }
};
