// ═══════════════════════════════════════════════════════════
// Bot Configuration — KV Helpers + Default Config
// ═══════════════════════════════════════════════════════════

import type { BotConfig } from "./types";

export const DEFAULT_BOT_CONFIG: BotConfig = {
  botId: "A",
  strategy: "gex_fade",
  enabled: true,

  tickers: ["SPY", "QQQ", "NVDA", "TSLA", "AAPL", "AMZN", "META", "MSFT"],

  portfolioSize: 100000,
  riskPctGradeA: 3,
  riskPctGradeB: 2,
  maxContracts: 50,
  maxOpenPositions: 3,

  activeHoursStart: "09:30",
  activeHoursEnd:   "15:45",
  forceCloseTime:   "15:45",
  cooldownMinutes:  30,
  maxTradesPerDay:  10,
  dailyLossLimit:   -2000,

  minGrade:           "B",
  minConfluenceScore: 5,
  minWallClass:       "MODERATE",
  regimeFilter:       "both",

  exitTrigger:        "stock_price",
  gradeAMinReturnPct: 50,
  gradeBMinReturnPct: 20,

  minOI:        100,
  maxSpreadPct: 25,
  minVolume:    10,
  maxDte:       1,
};

// Bot B — Trend Follow: Grade A only, higher confluence bar, positive GEX only
export const DEFAULT_BOT_CONFIG_B: BotConfig = {
  ...DEFAULT_BOT_CONFIG,
  botId: "B",
  strategy: "trend_follow",
  enabled: false,                   // starts disabled — enable via Settings

  tickers: ["SPY", "QQQ", "NVDA", "TSLA", "AAPL", "MSFT"],

  maxOpenPositions: 2,
  cooldownMinutes:  45,
  maxTradesPerDay:  6,
  dailyLossLimit:   -1500,

  minGrade:           "A",          // Grade A only
  minConfluenceScore: 7,
  minWallClass:       "STRONG",
  regimeFilter:       "positive",   // positive GEX only

  gradeAMinReturnPct: 75,
  gradeBMinReturnPct: 30,
};

// Bot C — Delta Wall: 0-DTE scalps at impenetrable walls, tighter risk
export const DEFAULT_BOT_CONFIG_C: BotConfig = {
  ...DEFAULT_BOT_CONFIG,
  botId: "C",
  strategy: "delta_wall",
  enabled: false,

  tickers: ["SPY", "QQQ", "NVDA", "TSLA"],

  riskPctGradeA:    2,
  riskPctGradeB:    1,
  maxContracts:     30,
  maxOpenPositions: 1,              // single position at a time

  activeHoursStart: "09:30",
  activeHoursEnd:   "14:00",        // morning session only
  forceCloseTime:   "14:00",
  cooldownMinutes:  60,
  maxTradesPerDay:  4,
  dailyLossLimit:   -1000,

  minGrade:           "B",
  minConfluenceScore: 6,
  minWallClass:       "IMPENETRABLE",
  regimeFilter:       "both",

  gradeAMinReturnPct: 60,
  gradeBMinReturnPct: 25,
  maxDte:             0,            // 0-DTE only
};

const BOT_DEFAULTS: Record<string, BotConfig> = {
  A: DEFAULT_BOT_CONFIG,
  B: DEFAULT_BOT_CONFIG_B,
  C: DEFAULT_BOT_CONFIG_C,
};

const KV_KEY = (botId: string) => `bot:config:${botId}`;

export async function getBotConfig(cache: KVNamespace, botId = "A"): Promise<BotConfig> {
  const defaults = BOT_DEFAULTS[botId] ?? { ...DEFAULT_BOT_CONFIG, botId };
  try {
    const raw = await cache.get(KV_KEY(botId), "json");
    if (raw && typeof raw === "object") {
      // Merge with bot-specific defaults so any new fields are always present
      return { ...defaults, ...(raw as Partial<BotConfig>), botId };
    }
  } catch {}
  return { ...defaults, botId };
}

export async function setBotConfig(cache: KVNamespace, config: BotConfig): Promise<void> {
  await cache.put(KV_KEY(config.botId), JSON.stringify(config));
}

// ── ET time helpers ──────────────────────────────────────

export function getETMinutes(): number {
  const now = new Date();
  // Use Intl to get ET time (handles DST automatically)
  const etStr = now.toLocaleString("en-US", {
    timeZone: "America/New_York",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  // etStr = "HH:MM"
  const [h, m] = etStr.split(":").map(Number);
  return h * 60 + m;
}

export function parseETMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

export function isInActiveHours(cfg: BotConfig): boolean {
  const now = getETMinutes();
  return now >= parseETMinutes(cfg.activeHoursStart) &&
         now <= parseETMinutes(cfg.activeHoursEnd);
}

export function isPastForceCloseTime(cfg: BotConfig): boolean {
  return getETMinutes() >= parseETMinutes(cfg.forceCloseTime);
}
