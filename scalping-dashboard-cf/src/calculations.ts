// ═══════════════════════════════════════════════════════════
// Calculations — ported from app.py (Python → TypeScript)
// All numpy operations replaced with pure JS
// ═══════════════════════════════════════════════════════════

import type {
  OptionRow,
  WallData,
  VolumeProfile,
  ProfileBin,
  ConfluenceLevel,
  ScalpSignal,
  OptionsSignal,
  SRLevel,
  BarData,
  PriceZone,
  TradeStyle,
} from "./types";

// ── Constants ────────────────────────────────────────────

const GAMMA_IMPENETRABLE = 8.0;
const GAMMA_STRONG = 4.0;
const GAMMA_MODERATE = 2.0;

// ── Math Helpers (numpy replacements) ────────────────────

function linspace(min: number, max: number, count: number): number[] {
  if (count <= 1) return [min];
  return Array.from(
    { length: count },
    (_, i) => min + ((max - min) * i) / (count - 1)
  );
}

function percentile(arr: number[], p: number): number {
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = (p / 100) * (sorted.length - 1);
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
}

function argmax(arr: number[]): number {
  let maxIdx = 0;
  for (let i = 1; i < arr.length; i++) {
    if (arr[i] > arr[maxIdx]) maxIdx = i;
  }
  return maxIdx;
}

function argsortDesc(arr: number[]): number[] {
  return Array.from({ length: arr.length }, (_, i) => i).sort(
    (a, b) => arr[b] - arr[a]
  );
}

function round2(x: number): number {
  return Math.round(x * 100) / 100;
}

function round4(x: number): number {
  return Math.round(x * 10000) / 10000;
}

// ═══════════════════════════════════════════════════════════
// PARSE CHAIN
// ═══════════════════════════════════════════════════════════

export function parseChain(
  rawChain: any[],
  spot: number,
  expiration: string
): [OptionRow[], number] {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const expDate = new Date(expiration + "T00:00:00Z");
  const dte = Math.max(
    Math.floor(
      (expDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24)
    ),
    1
  );

  const rows: OptionRow[] = [];

  for (const item of rawChain) {
    const details = item.details || {};
    const greeks = item.greeks || {};
    const quote = item.last_quote || {};
    const day = item.day || {};

    const strike = details.strike_price;
    const rightRaw = (details.contract_type || "").toLowerCase();
    if (!strike || !rightRaw) continue;

    const gamma = greeks.gamma || 0;
    const delta = greeks.delta || 0;
    const oi = item.open_interest || 0;
    const iv = item.implied_volatility || 0;
    const vol = day.volume || 0;

    const sign = rightRaw === "call" ? 1 : -1;
    const gex = sign * gamma * oi * 100 * spot * spot * 0.01;
    const dex = sign * delta * oi * 100;

    // Derive mid price: prefer last_quote, fall back to day data
    const rawBid = quote.bid ?? null;
    const rawAsk = quote.ask ?? null;
    const quoteMid = quote.midpoint ?? null;
    const dayMid = day.close ?? day.vwap ?? null;
    const mid = quoteMid ?? (rawBid != null && rawAsk != null ? round2((rawBid + rawAsk) / 2) : null) ?? dayMid;

    rows.push({
      strike,
      right: rightRaw === "call" ? "C" : "P",
      expiration,
      dte,
      bid: rawBid,
      ask: rawAsk,
      mid,
      volume: vol,
      oi,
      iv,
      delta: greeks.delta ?? null,
      gamma: greeks.gamma ?? null,
      theta: greeks.theta ?? null,
      vega: greeks.vega ?? null,
      gex: round2(gex),
      dex: round2(dex),
      gex_norm: 0,
      oi_norm: 0,
    });
  }

  return [rows, dte];
}

// ═══════════════════════════════════════════════════════════
// GAMMA WALLS
// ═══════════════════════════════════════════════════════════

function classifyWall(ratio: number): {
  classification: WallData["classification"];
  allow_breakout: boolean;
  action: string;
} {
  if (ratio >= GAMMA_IMPENETRABLE) {
    return {
      classification: "IMPENETRABLE",
      allow_breakout: false,
      action: "HARD_REVERSE_OR_PIN",
    };
  } else if (ratio >= GAMMA_STRONG) {
    return {
      classification: "STRONG",
      allow_breakout: false,
      action: "FADE_WITH_CONFIDENCE",
    };
  } else if (ratio >= GAMMA_MODERATE) {
    return {
      classification: "MODERATE",
      allow_breakout: true,
      action: "FADE_WITH_CAUTION",
    };
  } else {
    return {
      classification: "WEAK",
      allow_breakout: true,
      action: "EXPECT_BREACH",
    };
  }
}

export function computeGammaWalls(
  rows: OptionRow[],
  spot: number
): [Record<string, WallData>, number, string] {
  // Aggregate GEX by strike
  const strikeGex = new Map<number, number>();
  for (const r of rows) {
    strikeGex.set(r.strike, (strikeGex.get(r.strike) || 0) + r.gex);
  }

  const totalGex = rows.reduce((sum, r) => sum + r.gex, 0);
  const regime = totalGex >= 0 ? "POSITIVE_GAMMA" : "NEGATIVE_GAMMA";

  const walls: Record<string, WallData> = {};

  // Call wall: strike above spot with highest positive GEX
  const callsAbove = new Map<number, number>();
  for (const [s, g] of strikeGex) {
    if (s > spot && g > 0) callsAbove.set(s, g);
  }

  if (callsAbove.size > 0) {
    let cwStrike = 0;
    let cwGex = -Infinity;
    for (const [s, g] of callsAbove) {
      if (g > cwGex) {
        cwStrike = s;
        cwGex = g;
      }
    }

    // Next nearest
    let nextGex = 0;
    for (const [s, g] of callsAbove) {
      if (s !== cwStrike && g > nextGex) nextGex = g;
    }
    const ratio = nextGex !== 0 ? Math.abs(cwGex / nextGex) : 999;

    walls["CALL_WALL"] = {
      strike: cwStrike,
      gex: round2(cwGex),
      ratio: round2(ratio),
      ...classifyWall(ratio),
    };
  }

  // Put wall: strike below spot with most negative GEX
  const putsBelow = new Map<number, number>();
  for (const [s, g] of strikeGex) {
    if (s < spot && g < 0) putsBelow.set(s, g);
  }

  if (putsBelow.size > 0) {
    let pwStrike = 0;
    let pwGex = Infinity;
    for (const [s, g] of putsBelow) {
      if (g < pwGex) {
        pwStrike = s;
        pwGex = g;
      }
    }

    // Next nearest (most negative after the wall)
    let nextGex = 0;
    for (const [s, g] of putsBelow) {
      if (s !== pwStrike && g < nextGex) nextGex = g;
    }
    const ratio =
      nextGex !== 0 ? Math.abs(pwGex / nextGex) : 999;

    walls["PUT_WALL"] = {
      strike: pwStrike,
      gex: round2(pwGex),
      ratio: round2(ratio),
      ...classifyWall(ratio),
    };
  }

  return [walls, round2(totalGex), regime];
}

// ═══════════════════════════════════════════════════════════
// DELTA EXPOSURE
// ═══════════════════════════════════════════════════════════

export function computeDex(rows: OptionRow[]): [number, string] {
  const totalDex = rows.reduce((sum, r) => sum + r.dex, 0);
  const bias =
    totalDex > 0 ? "BULLISH" : totalDex < 0 ? "BEARISH" : "NEUTRAL";
  return [round2(totalDex), bias];
}

// ═══════════════════════════════════════════════════════════
// EXPECTED MOVE
// ═══════════════════════════════════════════════════════════

export function computeExpectedMove(
  rows: OptionRow[],
  spot: number,
  dte: number
): number | null {
  const ivs = rows.filter((r) => r.iv > 0).map((r) => r.iv);
  if (ivs.length === 0) return null;
  const avgIv = ivs.reduce((a, b) => a + b, 0) / ivs.length;
  return round2(spot * avgIv * Math.sqrt(dte / 365));
}

// ═══════════════════════════════════════════════════════════
// NORMALIZATIONS
// ═══════════════════════════════════════════════════════════

export function computeNormalizations(
  rows: OptionRow[],
  totalGex: number
): OptionRow[] {
  const totalOi = rows.reduce((sum, r) => sum + r.oi, 0);
  for (const r of rows) {
    r.gex_norm = totalGex !== 0 ? round4(r.gex / totalGex) : 0;
    r.oi_norm = totalOi !== 0 ? round4(r.oi / totalOi) : 0;
  }
  return rows;
}

// ═══════════════════════════════════════════════════════════
// VOLUME PROFILE
// ═══════════════════════════════════════════════════════════

export function buildVolumeProfile(
  bars: BarData[],
  numBins: number = 50
): VolumeProfile {
  if (bars.length === 0) {
    return {
      poc: null,
      hvn_levels: [],
      lvn_levels: [],
      value_area_high: null,
      value_area_low: null,
      profile: [],
    };
  }

  const lows = bars.map((b) => b.l);
  const highs = bars.map((b) => b.h);
  const priceMin = Math.min(...lows);
  const priceMax = Math.max(...highs);

  // np.linspace → bin edges
  const binEdges = linspace(priceMin, priceMax, numBins + 1);
  // bin centers
  const binCenters = binEdges
    .slice(0, -1)
    .map((e, i) => (e + binEdges[i + 1]) / 2);
  // np.zeros → volume accumulator
  const volumeAtPrice = new Array(numBins).fill(0);

  // Distribute bar volume across bins by overlap
  for (const bar of bars) {
    const barLow = bar.l;
    const barHigh = bar.h;
    const barVol = bar.v;
    const barRange = barHigh !== barLow ? barHigh - barLow : 0.01;

    for (let i = 0; i < numBins; i++) {
      if (barLow <= binCenters[i] && binCenters[i] <= barHigh) {
        const overlap =
          Math.min(binEdges[i + 1], barHigh) -
          Math.max(binEdges[i], barLow);
        volumeAtPrice[i] += barVol * (overlap / barRange);
      }
    }
  }

  // Classify bins — only keep top N most significant nodes
  const MAX_HVN = 5;
  const MAX_LVN = 5;

  const pocIdx = argmax(volumeAtPrice);
  const pocPrice = binCenters[pocIdx];

  // HVN: top N bins by volume (excluding POC), sorted by volume desc
  const hvnCandidates: { idx: number; vol: number }[] = [];
  for (let i = 0; i < numBins; i++) {
    if (i !== pocIdx) {
      hvnCandidates.push({ idx: i, vol: volumeAtPrice[i] });
    }
  }
  hvnCandidates.sort((a, b) => b.vol - a.vol);
  const hvnLevels = hvnCandidates
    .slice(0, MAX_HVN)
    .map((c) => binCenters[c.idx]);

  // LVN: bottom N bins by volume (only bins with some volume > 0), sorted by volume asc
  const lvnCandidates: { idx: number; vol: number }[] = [];
  for (let i = 0; i < numBins; i++) {
    if (volumeAtPrice[i] > 0) {
      lvnCandidates.push({ idx: i, vol: volumeAtPrice[i] });
    }
  }
  lvnCandidates.sort((a, b) => a.vol - b.vol);
  const lvnLevels = lvnCandidates
    .slice(0, MAX_LVN)
    .map((c) => binCenters[c.idx]);

  // Thresholds for profile display classification
  const hvnThreshold = percentile(volumeAtPrice, 70);
  const lvnThreshold = percentile(volumeAtPrice, 30);

  // Value area (68% of volume)
  const sortedIndices = argsortDesc(volumeAtPrice);
  const totalVol = volumeAtPrice.reduce((a: number, b: number) => a + b, 0);
  let cumulative = 0;
  const vaIndices: number[] = [];
  for (const idx of sortedIndices) {
    vaIndices.push(idx);
    cumulative += volumeAtPrice[idx];
    if (cumulative >= totalVol * 0.68) break;
  }
  const vaPrices = vaIndices.map((i) => binCenters[i]);

  // Build profile array
  const profile: ProfileBin[] = [];
  for (let i = 0; i < numBins; i++) {
    let nodeType: ProfileBin["node_type"] = "NORMAL";
    if (i === pocIdx) nodeType = "POC";
    else if (volumeAtPrice[i] >= hvnThreshold) nodeType = "HVN";
    else if (volumeAtPrice[i] <= lvnThreshold) nodeType = "LVN";

    profile.push({
      price: round2(binCenters[i]),
      volume: Math.round(volumeAtPrice[i]),
      node_type: nodeType,
    });
  }

  return {
    poc: round2(pocPrice),
    hvn_levels: hvnLevels.sort((a, b) => a - b).map(round2),
    lvn_levels: lvnLevels.sort((a, b) => a - b).map(round2),
    value_area_high: vaPrices.length > 0 ? round2(Math.max(...vaPrices)) : null,
    value_area_low: vaPrices.length > 0 ? round2(Math.min(...vaPrices)) : null,
    profile,
  };
}

// ═══════════════════════════════════════════════════════════
// CONFLUENCE SCORING (0–10 scale)
// ═══════════════════════════════════════════════════════════

export function confluenceEngine(
  walls: Record<string, WallData>,
  vp: VolumeProfile,
  spot: number,
  deltaBias: string,
  regime: string,
  expectedMove: number | null
): ConfluenceLevel[] {
  const confluence: ConfluenceLevel[] = [];
  const poc = vp.poc;
  const hvnLevels = vp.hvn_levels;
  const lvnLevels = vp.lvn_levels;
  const bufferPct = 0.005;

  for (const [wallName, wallData] of Object.entries(walls)) {
    const ws = wallData.strike;
    let score = 5; // Base score
    const details: string[] = ["Base: 5"];

    // Wall classification
    const cls = wallData.classification;
    if (cls === "IMPENETRABLE") { score += 2; details.push("+2 IMPENETRABLE wall"); }
    else if (cls === "STRONG") { score += 1; details.push("+1 STRONG wall"); }
    else if (cls === "MODERATE") { score -= 1; details.push("-1 MODERATE wall"); }
    else if (cls === "WEAK") { score -= 2; details.push("-2 WEAK wall"); }

    // Volume node alignment at wall
    let vpNode: string | null = null;
    if (poc && Math.abs(ws - poc) / poc <= bufferPct) {
      score += 2;
      vpNode = "POC";
      details.push("+2 POC at wall");
    } else {
      for (const hvn of hvnLevels) {
        if (Math.abs(ws - hvn) / hvn <= bufferPct) {
          score += 1;
          vpNode = "HVN";
          details.push("+1 HVN at wall");
          break;
        }
      }
    }

    // Delta bias alignment
    const wallDir = wallName === "CALL_WALL" ? "SHORT" : "LONG";
    const biasDir = deltaBias === "BULLISH" ? "LONG" : deltaBias === "BEARISH" ? "SHORT" : null;
    if (biasDir && biasDir === wallDir) {
      // At call wall, bearish bias aligns with SHORT; at put wall, bullish aligns with LONG
      score += 1;
      details.push("+1 delta bias aligns");
    } else if (biasDir && biasDir !== wallDir) {
      score -= 1;
      details.push("-1 delta bias conflicts");
    }

    // Regime alignment
    const tradeStyle = regime === "POSITIVE_GAMMA" ? "FADE" : "MOMENTUM";
    // Fading at walls is the right play in positive gamma
    if (tradeStyle === "FADE") {
      score += 1;
      details.push("+1 FADE regime aligns with wall trade");
    }

    // LVN between entry and target = fast move zone
    const midpoint = walls["CALL_WALL"] && walls["PUT_WALL"]
      ? (walls["CALL_WALL"].strike + walls["PUT_WALL"].strike) / 2
      : spot;
    const targetPrice = midpoint;
    const lo = Math.min(ws, targetPrice);
    const hi = Math.max(ws, targetPrice);
    const hasLvnBetween = lvnLevels.some((l) => l > lo && l < hi);
    if (hasLvnBetween) {
      score += 1;
      details.push("+1 LVN fast move zone");
    }

    // Price at POC penalty
    if (poc && Math.abs(spot - poc) / poc <= 0.002) {
      score -= 2;
      details.push("-2 price at POC (no edge)");
    }

    // Target beyond expected move penalty
    if (expectedMove) {
      const targetDist = Math.abs(ws - spot);
      if (targetDist > expectedMove) {
        score -= 1;
        details.push("-1 target beyond expected move");
      }
    }

    // Clamp to 0-10
    score = Math.max(0, Math.min(10, score));

    const strength: ConfluenceLevel["strength"] =
      score >= 7 ? "HIGH" : score >= 5 ? "MEDIUM" : "LOW";

    confluence.push({
      price: round2(ws),
      wall: wallName,
      wall_classification: cls,
      vol_node: vpNode,
      score,
      strength,
      details,
    });
  }

  return confluence;
}

// ═══════════════════════════════════════════════════════════
// RANGE POSITION (WALLS-FIRST)
// ═══════════════════════════════════════════════════════════

interface RangeInfo {
  rangeWidthPct: number;
  positionInRange: number;
  rangeZone: "NEAR_PUT_WALL" | "NEAR_CALL_WALL" | "MID_RANGE" | "OUTSIDE_ABOVE" | "OUTSIDE_BELOW" | "NO_RANGE";
}

function computeRangePosition(
  spot: number,
  cwStrike: number | null,
  pwStrike: number | null,
): RangeInfo {
  if (!cwStrike || !pwStrike) {
    return { rangeWidthPct: 0, positionInRange: 0.5, rangeZone: "NO_RANGE" };
  }
  const rangeWidthPct = (cwStrike - pwStrike) / spot;
  if (spot >= cwStrike) {
    return { rangeWidthPct, positionInRange: 1.0, rangeZone: "OUTSIDE_ABOVE" };
  }
  if (spot <= pwStrike) {
    return { rangeWidthPct, positionInRange: 0.0, rangeZone: "OUTSIDE_BELOW" };
  }
  const positionInRange = (spot - pwStrike) / (cwStrike - pwStrike);
  let rangeZone: RangeInfo["rangeZone"];
  if (positionInRange <= 0.25) rangeZone = "NEAR_PUT_WALL";
  else if (positionInRange >= 0.75) rangeZone = "NEAR_CALL_WALL";
  else rangeZone = "MID_RANGE";
  return { rangeWidthPct, positionInRange, rangeZone };
}

// ═══════════════════════════════════════════════════════════
// QUICK OPTION ESTIMATE (for smart target pre-check)
// ═══════════════════════════════════════════════════════════

interface QuickOptionEstimate {
  delta: number;
  gamma: number;
  entryPremium: number;
}

function findBestOptionEstimate(
  chain: OptionRow[],
  direction: "LONG" | "SHORT",
): QuickOptionEstimate | null {
  const wantRight: "C" | "P" = direction === "LONG" ? "C" : "P";
  const candidates = chain.filter((o) => {
    if (o.right !== wantRight) return false;
    if (o.delta == null || o.gamma == null) return false;
    if (o.mid == null || o.mid <= 0) return false;
    const absDelta = Math.abs(o.delta);
    if (absDelta < 0.20 || absDelta > 0.50) return false;
    if (o.oi < 50) return false;
    return true;
  });
  if (candidates.length === 0) return null;
  candidates.sort(
    (a, b) => Math.abs(Math.abs(a.delta!) - 0.35) - Math.abs(Math.abs(b.delta!) - 0.35),
  );
  const best = candidates[0];
  return { delta: best.delta!, gamma: best.gamma!, entryPremium: best.mid! };
}

// ═══════════════════════════════════════════════════════════
// SMART TARGET SELECTION
// ═══════════════════════════════════════════════════════════

interface SmartTargetResult {
  target: number;
  targetLabel: string;
  estimatedOptionReturnPct: number;
  usedFallback: boolean;
}

function selectSmartTarget(
  direction: "LONG" | "SHORT",
  entry: number,
  oppositeWallStrike: number | null,
  hvnLevels: number[],
  poc: number | null,
  midpoint: number | null,
  optEst: QuickOptionEstimate | null,
  minReturnPct: number,
  fallbackPct: number,
  minTargetDist: number,
): SmartTargetResult | null {
  const candidates: { price: number; label: string }[] = [];

  // Collect HVN targets
  for (const hvn of hvnLevels) {
    const inDir = direction === "LONG" ? hvn > entry : hvn < entry;
    const dist = Math.abs(hvn - entry);
    const withinWall = direction === "LONG"
      ? (!oppositeWallStrike || hvn <= oppositeWallStrike)
      : (!oppositeWallStrike || hvn >= oppositeWallStrike);
    if (inDir && dist >= minTargetDist && withinWall) {
      candidates.push({ price: hvn, label: "HVN" });
    }
  }

  // POC
  if (poc) {
    const inDir = direction === "LONG" ? poc > entry : poc < entry;
    const dist = Math.abs(poc - entry);
    const withinWall = direction === "LONG"
      ? (!oppositeWallStrike || poc <= oppositeWallStrike)
      : (!oppositeWallStrike || poc >= oppositeWallStrike);
    if (inDir && dist >= minTargetDist && withinWall) {
      candidates.push({ price: poc, label: "POC" });
    }
  }

  // Midpoint (between walls)
  if (midpoint) {
    const inDir = direction === "LONG" ? midpoint > entry : midpoint < entry;
    const dist = Math.abs(midpoint - entry);
    if (inDir && dist >= minTargetDist) {
      candidates.push({ price: midpoint, label: "MIDPOINT" });
    }
  }

  // Opposite wall
  if (oppositeWallStrike) {
    const inDir = direction === "LONG" ? oppositeWallStrike > entry : oppositeWallStrike < entry;
    const dist = Math.abs(oppositeWallStrike - entry);
    if (inDir && dist >= minTargetDist) {
      candidates.push({ price: oppositeWallStrike, label: "OPPOSITE_WALL" });
    }
  }

  // Sort by distance (closest first)
  candidates.sort((a, b) => Math.abs(a.price - entry) - Math.abs(b.price - entry));

  // If no options data → pick first structural target
  if (!optEst || optEst.entryPremium <= 0) {
    if (candidates.length > 0) {
      return { target: candidates[0].price, targetLabel: candidates[0].label, estimatedOptionReturnPct: 0, usedFallback: false };
    }
    return { target: round2(direction === "LONG" ? entry * (1 + fallbackPct) : entry * (1 - fallbackPct)), targetLabel: "FALLBACK", estimatedOptionReturnPct: 0, usedFallback: true };
  }

  // Estimate option return for each candidate, pick first ≥ minReturnPct
  for (const c of candidates) {
    const stockMove = c.price - entry;
    const optionMove = optEst.delta * stockMove + 0.5 * optEst.gamma * stockMove * stockMove;
    const optionReturnPct = (optionMove / optEst.entryPremium) * 100;
    if (optionReturnPct >= minReturnPct) {
      return { target: c.price, targetLabel: c.label, estimatedOptionReturnPct: round2(optionReturnPct), usedFallback: false };
    }
  }

  // No target meets threshold
  return null;
}

// ═══════════════════════════════════════════════════════════
// PRICE ZONE DETECTION (WALLS-FIRST)
// ═══════════════════════════════════════════════════════════

function determinePriceZone(
  spot: number,
  cwStrike: number | null,
  pwStrike: number | null,
  poc: number | null,
  rangeInfo: RangeInfo,
): PriceZone {
  switch (rangeInfo.rangeZone) {
    case "OUTSIDE_ABOVE":
    case "NEAR_CALL_WALL":
      return "AT_CALL_WALL";
    case "OUTSIDE_BELOW":
    case "NEAR_PUT_WALL":
      return "AT_PUT_WALL";
    case "MID_RANGE":
      if (poc && Math.abs(spot - poc) / poc <= 0.002) return "AT_POC";
      if (poc && spot > poc) return "ABOVE_POC";
      if (poc && spot < poc) return "BELOW_POC";
      if (cwStrike && pwStrike) {
        const mid = (cwStrike + pwStrike) / 2;
        return spot > mid ? "ABOVE_POC" : "BELOW_POC";
      }
      return "ABOVE_POC";
    case "NO_RANGE":
      if (cwStrike && spot >= cwStrike) return "AT_CALL_WALL";
      if (pwStrike && spot <= pwStrike) return "AT_PUT_WALL";
      if (poc && Math.abs(spot - poc) / poc <= 0.002) return "AT_POC";
      if (poc && spot > poc) return "ABOVE_POC";
      if (poc && spot < poc) return "BELOW_POC";
      return "ABOVE_POC";
  }
}

// ═══════════════════════════════════════════════════════════
// SCALP SIGNAL — Full Engine
// ═══════════════════════════════════════════════════════════

export function generateSignal(
  walls: Record<string, WallData>,
  vp: VolumeProfile,
  spot: number,
  totalGex: number,
  deltaBias: string,
  expectedMove: number | null,
  confluenceLevels: ConfluenceLevel[],
  chain: OptionRow[] = [],
): ScalpSignal {
  const callWall = walls["CALL_WALL"];
  const putWall = walls["PUT_WALL"];
  const cwStrike = callWall?.strike ?? null;
  const pwStrike = putWall?.strike ?? null;
  const poc = vp.poc;
  const hvnLevels = vp.hvn_levels;
  const lvnLevels = vp.lvn_levels;

  const regime = totalGex >= 0 ? "POSITIVE_GAMMA" : "NEGATIVE_GAMMA";
  const tradeStyle: TradeStyle = regime === "POSITIVE_GAMMA" ? "FADE" : "MOMENTUM";

  // ── WALLS-FIRST: compute range position ──────────────
  const rangeInfo = computeRangePosition(spot, cwStrike, pwStrike);
  const priceZone = determinePriceZone(spot, cwStrike, pwStrike, poc, rangeInfo);

  let midpoint: number | null = null;
  if (cwStrike && pwStrike) {
    midpoint = round2((cwStrike + pwStrike) / 2);
  }

  const minTargetDist = Math.max(spot * 0.005, 0.50);

  // Helper: check LVN between two prices
  function hasLvnBetween(a: number, b: number): boolean {
    const lo = Math.min(a, b);
    const hi = Math.max(a, b);
    return lvnLevels.some((l) => l > lo && l < hi);
  }

  // Helper: get confluence score for a wall
  function getWallConfluence(wallName: string): number {
    const cl = confluenceLevels.find((c) => c.wall === wallName);
    return cl ? cl.score : 5;
  }

  // ── Range too narrow → NO_TRADE ──────────────────────
  if (rangeInfo.rangeZone !== "NO_RANGE" && rangeInfo.rangeWidthPct < 0.005) {
    return noTrade("Walls too close (range < 0.5%) — no room to trade", priceZone, tradeStyle);
  }

  // ── NO_TRADE: universal checks ───────────────────────
  if (priceZone === "AT_POC") {
    return noTrade("Price within 0.2% of POC — no directional edge", priceZone, tradeStyle);
  }
  if (deltaBias === "NEUTRAL") {
    return noTrade("Delta bias is NEUTRAL — no directional conviction", priceZone, tradeStyle);
  }

  // ── Determine direction, entry, stop ─────────────────

  let direction: "LONG" | "SHORT";
  let entry: number;
  let stop: number;
  let entryType: string;
  let relevantWall: WallData | null = null;
  let oppositeWallStrike: number | null = null;
  let wallScore: number | null = null;

  if (priceZone === "AT_CALL_WALL" && callWall) {
    // ── AT CALL WALL (upper 25% or beyond): SHORT ──
    direction = "SHORT";
    relevantWall = callWall;
    entry = callWall.strike;
    stop = round2(entry * 1.0015);
    entryType = "WALL";
    oppositeWallStrike = pwStrike;

    // Wall must not be WEAK (mechanical requirement)
    if (callWall.classification === "WEAK") {
      return noTrade("At Call Wall but wall is WEAK — breach likely", priceZone, tradeStyle);
    }
    // Delta bias is a score modifier, NOT a hard blocker at walls
    wallScore = getWallConfluence("CALL_WALL");
    if (deltaBias === "BEARISH") wallScore += 1;       // bias aligns → bonus
    else if (deltaBias === "BULLISH") wallScore -= 1;   // bias conflicts → penalty
    wallScore = Math.max(0, Math.min(10, wallScore));
    if (wallScore < 5) {
      return noTrade(`Confluence score too low (${wallScore}/10)`, priceZone, tradeStyle);
    }

  } else if (priceZone === "AT_PUT_WALL" && putWall) {
    // ── AT PUT WALL (lower 25% or beyond): LONG ──
    direction = "LONG";
    relevantWall = putWall;
    entry = putWall.strike;
    stop = round2(entry * 0.9985);
    entryType = "WALL";
    oppositeWallStrike = cwStrike;

    // Wall must not be WEAK (mechanical requirement)
    if (putWall.classification === "WEAK") {
      return noTrade("At Put Wall but wall is WEAK — breach likely", priceZone, tradeStyle);
    }
    // Delta bias is a score modifier, NOT a hard blocker at walls
    wallScore = getWallConfluence("PUT_WALL");
    if (deltaBias === "BULLISH") wallScore += 1;        // bias aligns → bonus
    else if (deltaBias === "BEARISH") wallScore -= 1;    // bias conflicts → penalty
    wallScore = Math.max(0, Math.min(10, wallScore));
    if (wallScore < 5) {
      return noTrade(`Confluence score too low (${wallScore}/10)`, priceZone, tradeStyle);
    }

  } else {
    // ── MID RANGE (middle 50%) or NO_RANGE ──
    if (regime === "POSITIVE_GAMMA") {
      // FADE trades
      if (priceZone === "ABOVE_POC" && deltaBias === "BULLISH") {
        direction = "LONG";
        oppositeWallStrike = cwStrike;
      } else if (priceZone === "BELOW_POC" && deltaBias === "BEARISH") {
        direction = "SHORT";
        oppositeWallStrike = pwStrike;
      } else {
        return noTrade(`MID_RANGE ${priceZone}: ${deltaBias} bias conflicts for FADE`, priceZone, tradeStyle);
      }
    } else {
      // MOMENTUM trades
      if (priceZone === "ABOVE_POC" && deltaBias === "BULLISH") {
        direction = "LONG";
        oppositeWallStrike = cwStrike;
      } else if (priceZone === "BELOW_POC" && deltaBias === "BEARISH") {
        direction = "SHORT";
        oppositeWallStrike = pwStrike;
      } else {
        return noTrade(`MID_RANGE ${priceZone}: ${deltaBias} bias — no clear setup`, priceZone, tradeStyle);
      }
    }

    // Entry: nearest HVN or spot
    if (regime === "POSITIVE_GAMMA") {
      // FADE: entry at HVN on our side
      if (direction === "LONG") {
        const hvnBelow = hvnLevels.filter((h) => h < spot).sort((a, b) => b - a);
        entry = hvnBelow.length > 0 ? hvnBelow[0] : spot;
      } else {
        const hvnAbove = hvnLevels.filter((h) => h > spot).sort((a, b) => a - b);
        entry = hvnAbove.length > 0 ? hvnAbove[0] : spot;
      }
      entryType = "HVN";
    } else {
      // MOMENTUM: entry at HVN as breakout level
      if (direction === "LONG") {
        const hvnAbove = hvnLevels.filter((h) => h > spot).sort((a, b) => a - b);
        entry = hvnAbove.length > 0 ? hvnAbove[0] : spot;
      } else {
        const hvnBelow = hvnLevels.filter((h) => h < spot).sort((a, b) => b - a);
        entry = hvnBelow.length > 0 ? hvnBelow[0] : spot;
      }
      entryType = direction === "LONG" ? "HVN_BREAKOUT" : "HVN_BREAKDOWN";
    }

    stop = direction === "LONG" ? round2(entry * 0.9985) : round2(entry * 1.0015);
  }

  // ── SMART TARGET SELECTION (dual: Grade B ≥20%, Grade A ≥50%) ──
  const optEst = findBestOptionEstimate(chain, direction);

  // Grade B target: nearer, more achievable (≥20% option return)
  const smartTargetB = selectSmartTarget(
    direction, entry, oppositeWallStrike,
    hvnLevels, poc, midpoint, optEst,
    20, 0.005, minTargetDist,
  );

  if (!smartTargetB) {
    return noTrade("No target gives +20% option return — not worth the trade", priceZone, tradeStyle);
  }

  // Grade A target: farther, bigger reward (≥50% option return)
  const smartTargetA = selectSmartTarget(
    direction, entry, oppositeWallStrike,
    hvnLevels, poc, midpoint, optEst,
    50, 0.005, minTargetDist,
  );

  const target = smartTargetB.target;
  const target_a = smartTargetA?.target ?? null;

  // ── Volume profile quality ───────────────────────────
  const fastMove = hasLvnBetween(entry, target);
  const lo = Math.min(entry, target);
  const hi = Math.max(entry, target);
  const hvnObstacles = hvnLevels.filter((h) => h > lo && h < hi).length;

  // ── Confluence scoring ───────────────────────────────
  const score = wallScore ?? computeInsideScore(
    walls, vp, deltaBias, regime, direction, entry, target,
    expectedMove, spot, confluenceLevels,
  );

  // Mid-range needs higher confluence (≥6 instead of ≥5)
  const minScore = rangeInfo.rangeZone === "MID_RANGE" ? 6 : 5;
  if (score < minScore) {
    return noTrade(`Confluence score too low (${score}/10, need ${minScore})`, priceZone, tradeStyle);
  }

  // ── Expected move check ──────────────────────────────
  if (expectedMove && Math.abs(target - entry) > expectedMove) {
    return noTrade("Target distance exceeds expected move", priceZone, tradeStyle);
  }

  // ── Build reason string ──────────────────────────────
  const optReturnB = smartTargetB.estimatedOptionReturnPct > 0
    ? ` B~+${smartTargetB.estimatedOptionReturnPct.toFixed(0)}%` : "";
  const optReturnA = smartTargetA && smartTargetA.estimatedOptionReturnPct > 0
    ? ` A~+${smartTargetA.estimatedOptionReturnPct.toFixed(0)}%` : "";
  const obstacleNote = hvnObstacles > 0 ? `, ${hvnObstacles} HVN obstacle(s)` : "";
  const styleLabel = regime === "POSITIVE_GAMMA" ? "FADE" : "MOMENTUM";
  const targetANote = target_a ? ` | A→$${target_a.toFixed(2)}` : "";
  const reason = `${styleLabel} ${direction} from $${entry.toFixed(2)} → $${target.toFixed(2)} (${smartTargetB.targetLabel})${targetANote}${fastMove ? ", LVN fast move" : ""}${obstacleNote}${optReturnB}${optReturnA}`;

  return makeFullSignal(
    direction, entry, target, target_a, stop, entryType,
    relevantWall, score, fastMove, priceZone, tradeStyle, reason,
  );
}

// ── Confluence score for inside-range trades ──────────

function computeInsideScore(
  walls: Record<string, WallData>,
  vp: VolumeProfile,
  deltaBias: string,
  regime: string,
  direction: "LONG" | "SHORT",
  entry: number,
  target: number,
  expectedMove: number | null,
  spot: number,
  confluenceLevels: ConfluenceLevel[]
): number {
  let score = 5;
  const poc = vp.poc;
  const hvnLevels = vp.hvn_levels;
  const lvnLevels = vp.lvn_levels;
  const bufferPct = 0.005;

  // Nearest wall
  const relevantWall = direction === "LONG" ? walls["PUT_WALL"] : walls["CALL_WALL"];
  if (relevantWall) {
    const cls = relevantWall.classification;
    if (cls === "IMPENETRABLE") score += 2;
    else if (cls === "STRONG") score += 1;
    else if (cls === "MODERATE") score -= 1;
    else if (cls === "WEAK") score -= 2;
  }

  // Volume node at entry
  if (poc && Math.abs(entry - poc) / poc <= bufferPct) {
    score += 2;
  } else if (hvnLevels.some((h) => Math.abs(entry - h) / h <= bufferPct)) {
    score += 1;
  }

  // Delta bias alignment
  const biasDir = deltaBias === "BULLISH" ? "LONG" : deltaBias === "BEARISH" ? "SHORT" : null;
  if (biasDir === direction) score += 1;
  else if (biasDir && biasDir !== direction) score -= 1;

  // Regime alignment
  const tradeStyle = regime === "POSITIVE_GAMMA" ? "FADE" : "MOMENTUM";
  if (
    (tradeStyle === "FADE" && regime === "POSITIVE_GAMMA") ||
    (tradeStyle === "MOMENTUM" && regime === "NEGATIVE_GAMMA")
  ) {
    score += 1;
  }

  // LVN between entry and target
  const lo = Math.min(entry, target);
  const hi = Math.max(entry, target);
  if (lvnLevels.some((l) => l > lo && l < hi)) {
    score += 1;
  }

  // Price at POC penalty
  if (poc && Math.abs(spot - poc) / poc <= 0.002) {
    score -= 2;
  }

  // Target beyond expected move
  if (expectedMove && Math.abs(target - entry) > expectedMove) {
    score -= 1;
  }

  return Math.max(0, Math.min(10, score));
}

// ── Helper: build NO_TRADE signal ────────────────────

function noTrade(reason: string, priceZone: PriceZone, tradeStyle: TradeStyle): ScalpSignal {
  return {
    direction: "NO_TRADE",
    reason,
    confluence_score: 0,
    signal_strength: "N/A",
    tradeable: false,
    fast_move_zone: false,
    price_zone: priceZone,
    trade_style: tradeStyle,
  };
}

// ── Helper: build full signal ────────────────────────

function makeFullSignal(
  direction: "LONG" | "SHORT",
  entry: number,
  target_b: number,
  target_a: number | null,
  stop: number,
  entryType: string,
  wall: WallData | null,
  score: number,
  fastMove: boolean,
  priceZone: PriceZone,
  tradeStyle: TradeStyle,
  reason: string
): ScalpSignal {
  const strength: ScalpSignal["signal_strength"] =
    score >= 7 ? "HIGH" : score >= 5 ? "MEDIUM" : "LOW";
  // Tighten stop in LVN fast move zone (0.10% instead of 0.15%)
  let finalStop = stop;
  if (fastMove) {
    if (direction === "LONG") {
      finalStop = round2(entry * 0.999);
    } else {
      finalStop = round2(entry * 1.001);
    }
  }
  return {
    direction,
    entry: round2(entry),
    target: round2(target_b),       // default = Grade B target (nearer)
    target_b: round2(target_b),     // Grade B: ≥20% option return
    target_a: target_a ? round2(target_a) : null, // Grade A: ≥50% option return (or null)
    stop: round2(finalStop),
    entry_type: entryType,
    wall_strike: wall?.strike,
    wall_class: wall?.classification,
    gamma_ratio: wall?.ratio,
    confluence_score: score,
    signal_strength: strength,
    tradeable: score >= 5,
    fast_move_zone: fastMove,
    price_zone: priceZone,
    trade_style: tradeStyle,
    reason,
  };
}

// ═══════════════════════════════════════════════════════════
// SUPPORT & RESISTANCE
// ═══════════════════════════════════════════════════════════

export function buildSupportResistance(
  walls: Record<string, WallData>,
  vp: VolumeProfile,
  spot: number
): SRLevel[] {
  const levels: SRLevel[] = [];

  const cw = walls["CALL_WALL"];
  const pw = walls["PUT_WALL"];

  if (cw) {
    levels.push({
      price: cw.strike,
      type: "RESISTANCE",
      source: "Call Wall",
      classification: cw.classification,
      strength: cw.ratio,
    });
  }

  if (pw) {
    levels.push({
      price: pw.strike,
      type: "SUPPORT",
      source: "Put Wall",
      classification: pw.classification,
      strength: pw.ratio,
    });
  }

  if (vp.poc) {
    levels.push({
      price: vp.poc,
      type: "SUPPORT/RESISTANCE",
      source: "POC",
      classification: "POC",
      strength: 0,
    });
  }

  if (vp.value_area_high) {
    levels.push({
      price: vp.value_area_high,
      type: "RESISTANCE",
      source: "VA High",
      classification: "",
      strength: 0,
    });
  }

  if (vp.value_area_low) {
    levels.push({
      price: vp.value_area_low,
      type: "SUPPORT",
      source: "VA Low",
      classification: "",
      strength: 0,
    });
  }

  for (const hvn of vp.hvn_levels.slice(0, 5)) {
    const sr: SRLevel["type"] = hvn < spot ? "SUPPORT" : "RESISTANCE";
    levels.push({
      price: hvn,
      type: sr,
      source: "HVN",
      classification: "",
      strength: 0,
    });
  }

  levels.sort((a, b) => a.price - b.price);
  return levels;
}

// ═══════════════════════════════════════════════════════════
// Options Trade Signal — Buy Calls / Puts
// Selects the best OTM contract (delta ~0.30-0.40) aligned
// with the stock scalp signal direction.
// ═══════════════════════════════════════════════════════════

export function generateOptionsSignal(
  chain: OptionRow[],
  signal: ScalpSignal,
  spot: number,
): OptionsSignal | null {
  if (signal.direction === "NO_TRADE" || !signal.tradeable) return null;
  if (!signal.entry || !signal.target || !signal.stop) return null;

  const wantRight: "C" | "P" = signal.direction === "LONG" ? "C" : "P";

  // ── Filter candidates ──────────────────────────────────
  const candidates = chain.filter((o) => {
    if (o.right !== wantRight) return false;
    if (o.delta == null || o.gamma == null || o.theta == null) return false;
    // Require mid price (from last_quote OR day.close fallback)
    if (o.mid == null || o.mid <= 0) return false;

    const absDelta = Math.abs(o.delta);
    // Acceptable range: 0.20 - 0.50 (prefer 0.30-0.40)
    if (absDelta < 0.20 || absDelta > 0.50) return false;

    // Minimum liquidity
    if (o.oi < 50) return false;

    return true;
  });

  if (candidates.length === 0) return null;

  // ── Score and sort candidates ──────────────────────────
  // Prefer: delta closest to 0.35, high OI, narrow spread
  const scored = candidates.map((o) => {
    const absDelta = Math.abs(o.delta!);
    // If bid/ask available, compute real spread; otherwise estimate ~8%
    // (near-ATM 0-DTE options on liquid tickers typically trade at 3–8% spread;
    //  15% was too conservative and permanently blocked Grade A)
    const hasBidAsk = o.bid != null && o.ask != null && o.bid > 0;
    const spread = hasBidAsk ? (o.ask! - o.bid!) : o.mid! * 0.08;
    const spreadPct = spread / o.mid! * 100;

    // Delta fit score (0-10): closer to 0.35 = better
    const deltaScore = 10 - Math.abs(absDelta - 0.35) * 40;

    // Liquidity score (0-10)
    const oiScore = Math.min(o.oi / 500, 10);
    const volScore = Math.min(o.volume / 100, 5);

    // Spread score (0-10): tighter = better
    const spreadScore = Math.max(0, 10 - spreadPct);

    const total = deltaScore * 3 + oiScore * 2 + volScore * 1 + spreadScore * 2;

    return { option: o, score: total, spreadPct };
  });

  scored.sort((a, b) => b.score - a.score);

  const best = scored[0];
  const o = best.option;

  // ── Compute options pricing ────────────────────────────
  const entryPremium = round2(o.mid!);
  const delta = o.delta!;
  const gamma = o.gamma!;

  // Estimate premium at stock target
  const stockMoveToTarget = signal.target! - signal.entry!;
  // P(target) ≈ mid + delta × move + 0.5 × gamma × move²
  const targetPremium = round2(Math.max(
    0.01,
    entryPremium + delta * stockMoveToTarget + 0.5 * gamma * stockMoveToTarget * stockMoveToTarget,
  ));

  // Estimate premium at stock stop
  const stockMoveToStop = signal.stop! - signal.entry!;
  const stopPremium = round2(Math.max(
    0.01,
    entryPremium + delta * stockMoveToStop + 0.5 * gamma * stockMoveToStop * stockMoveToStop,
  ));

  const expectedReturnPct = round2(((targetPremium - entryPremium) / entryPremium) * 100);
  const maxLoss = round2(entryPremium * 100);

  // Break-even
  const breakEven = round2(
    wantRight === "C"
      ? o.strike + entryPremium
      : o.strike - entryPremium,
  );

  // ── Quality grade ──────────────────────────────────────
  const absDelta = Math.abs(delta);
  const spreadPct = best.spreadPct;
  let grade: "A" | "B" | "C" = "C";

  if (
    absDelta >= 0.28 && absDelta <= 0.42 &&
    spreadPct < 12 &&
    o.oi >= 500 &&
    o.volume >= 50
  ) {
    grade = "A";
  } else if (
    absDelta >= 0.22 && absDelta <= 0.48 &&
    spreadPct < 25 &&
    o.oi >= 100 &&
    o.volume >= 10
  ) {
    grade = "B";
  }

  // Build reason — include grade factors for debugging
  const typeLabel = wantRight === "C" ? "Call" : "Put";
  const hasBidAskFinal = o.bid != null && o.ask != null && o.bid > 0;
  const spreadNote = hasBidAskFinal ? `spd:${spreadPct.toFixed(1)}%` : `spd:~${spreadPct.toFixed(1)}%(est)`;
  const reason =
    `Buy ${typeLabel} $${o.strike} ` +
    `(${o.expiration}, ${o.dte}d) ` +
    `Δ${delta.toFixed(2)} ` +
    `@ $${entryPremium.toFixed(2)} → $${targetPremium.toFixed(2)} ` +
    `(${expectedReturnPct > 0 ? "+" : ""}${expectedReturnPct.toFixed(0)}%) ` +
    `[OI:${o.oi} Vol:${o.volume} ${spreadNote}] Grade ${grade}`;

  // Derive bid/ask: use real values or estimate from mid
  const finalBid = o.bid != null && o.bid > 0 ? o.bid : round2(entryPremium * 0.93);
  const finalAsk = o.ask != null && o.ask > 0 ? o.ask : round2(entryPremium * 1.07);

  return {
    contract_type: wantRight === "C" ? "CALL" : "PUT",
    strike: o.strike,
    expiration: o.expiration,
    dte: o.dte,
    bid: finalBid,
    ask: finalAsk,
    entry_premium: entryPremium,
    target_premium: targetPremium,
    stop_premium: stopPremium,
    max_loss_per_contract: maxLoss,
    expected_return_pct: expectedReturnPct,
    break_even: breakEven,
    delta: round2(delta * 100) / 100,
    gamma: round2(gamma * 10000) / 10000,
    theta: round2((o.theta ?? 0) * 100) / 100,
    iv: round2((o.iv ?? 0) * 100),
    volume: o.volume,
    open_interest: o.oi,
    bid_ask_spread_pct: round2(spreadPct),
    grade,
    reason,
  };
}
