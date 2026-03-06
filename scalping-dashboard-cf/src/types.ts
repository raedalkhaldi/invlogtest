// ═══════════════════════════════════════════════════════════
// Cloudflare Environment Bindings
// ═══════════════════════════════════════════════════════════

export interface Env {
  MASSIVE_API_KEY: string;
  SCALPING_CACHE: KVNamespace;
  TELEGRAM_BOT_TOKEN: string;
  CRON_SECRET: string;
  // Bot A — default / fallback
  ALPACA_API_KEY: string;
  ALPACA_API_SECRET: string;
  // Bot B
  ALPACA_API_KEY_B: string;
  ALPACA_API_SECRET_B: string;
  // Bot C
  ALPACA_API_KEY_C: string;
  ALPACA_API_SECRET_C: string;
}

// ═══════════════════════════════════════════════════════════
// Option Row (parsed from API response)
// ═══════════════════════════════════════════════════════════

export interface OptionRow {
  strike: number;
  right: "C" | "P";
  expiration: string;
  dte: number;
  bid: number | null;
  ask: number | null;
  mid: number | null;
  volume: number;
  oi: number;
  iv: number;
  delta: number | null;
  gamma: number | null;
  theta: number | null;
  vega: number | null;
  gex: number;
  dex: number;
  gex_norm: number;
  oi_norm: number;
}

// ═══════════════════════════════════════════════════════════
// Gamma Wall
// ═══════════════════════════════════════════════════════════

export interface WallData {
  strike: number;
  gex: number;
  ratio: number;
  classification: "IMPENETRABLE" | "STRONG" | "MODERATE" | "WEAK";
  allow_breakout: boolean;
  action: string;
}

// ═══════════════════════════════════════════════════════════
// Volume Profile
// ═══════════════════════════════════════════════════════════

export interface ProfileBin {
  price: number;
  volume: number;
  node_type: "POC" | "HVN" | "LVN" | "NORMAL";
}

export interface VolumeProfile {
  poc: number | null;
  hvn_levels: number[];
  lvn_levels: number[];
  value_area_high: number | null;
  value_area_low: number | null;
  profile: ProfileBin[];
}

// ═══════════════════════════════════════════════════════════
// Confluence
// ═══════════════════════════════════════════════════════════

export interface ConfluenceLevel {
  price: number;
  wall: string;
  wall_classification: string;
  vol_node: string | null;
  score: number;
  strength: "HIGH" | "MEDIUM" | "LOW";
  details: string[];
}

// ═══════════════════════════════════════════════════════════
// Scalp Signal
// ═══════════════════════════════════════════════════════════

export type PriceZone =
  | "AT_CALL_WALL"
  | "AT_PUT_WALL"
  | "ABOVE_POC"
  | "BELOW_POC"
  | "AT_POC";

export type TradeStyle = "FADE" | "MOMENTUM";

export interface ScalpSignal {
  direction: "LONG" | "SHORT" | "NO_TRADE";
  entry?: number;
  target?: number | null;
  target_a?: number | null;   // Grade A target (≥50% option return — farther)
  target_b?: number | null;   // Grade B target (≥20% option return — nearer)
  stop?: number;
  entry_type?: string;
  wall_strike?: number;
  wall_class?: string;
  gamma_ratio?: number;
  confluence_score: number;
  signal_strength: "HIGH" | "MEDIUM" | "LOW" | "N/A";
  tradeable: boolean;
  fast_move_zone: boolean;
  price_zone: PriceZone;
  trade_style: TradeStyle;
  reason?: string;
  call_wall?: number | null;
  put_wall?: number | null;
  midpoint?: number | null;
  poc?: number | null;
}

// ═══════════════════════════════════════════════════════════
// Options Trade Signal
// ═══════════════════════════════════════════════════════════

export interface OptionsSignal {
  contract_type: "CALL" | "PUT" | "NONE";
  strike: number;
  expiration: string;
  dte: number;
  // Pricing
  bid: number;
  ask: number;
  entry_premium: number;       // mid price
  target_premium: number;      // estimated premium at stock target
  stop_premium: number;        // estimated premium at stock stop
  max_loss_per_contract: number; // entry_premium × 100
  expected_return_pct: number;
  break_even: number;
  // Greeks
  delta: number;
  gamma: number;
  theta: number;
  iv: number;
  // Liquidity
  volume: number;
  open_interest: number;
  bid_ask_spread_pct: number;
  // Quality
  grade: "A" | "B" | "C";
  reason: string;
}

// ═══════════════════════════════════════════════════════════
// Paper Trading Position
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// Pending Signal (waiting for stock to reach entry price)
// ═══════════════════════════════════════════════════════════

export interface PendingSignal {
  ticker: string;
  direction: "LONG" | "SHORT";
  stock_entry: number;        // stock price that triggers the option buy
  stock_target: number;       // stock price that triggers the option sell
  option_strike: number;
  option_expiration: string;
  contract_type: "CALL" | "PUT";
  signal_grade: "A" | "B";
  confidence_tier: number;
  created_at: string;
  expires_at: string;         // auto-expire at end of trading day
}

export interface PaperPosition {
  ticker: string;
  occ_symbol: string;
  contract_type: "CALL" | "PUT";
  strike: number;
  expiration: string;
  contracts: number;
  entry_premium: number;
  target_premium: number;     // kept for reference / Telegram display
  stop_premium: number;
  stock_target: number;       // stock price that triggers the option sell
  entry_time: string;
  signal_grade: string;
  confidence_tier: number;
  alpaca_order_id: string;
}

export interface ClosedTrade extends PaperPosition {
  exit_premium: number;
  exit_time: string;
  pnl_dollars: number;
  pnl_pct: number;
  result: "WIN" | "LOSS" | "EXPIRED";
}

// ═══════════════════════════════════════════════════════════
// Bot Configuration (stored in KV, editable via Settings UI)
// ═══════════════════════════════════════════════════════════

export interface BotConfig {
  // ── Identity ──────────────────────────────────────────
  botId: string;                      // "A" | "B" | "C"
  strategy: "gex_fade" | "trend_follow" | "delta_wall" | "max_pain_pin";
  enabled: boolean;

  // ── Tickers ───────────────────────────────────────────
  tickers: string[];                  // e.g. ["SPY","QQQ","NVDA","TSLA","AAPL","AMZN","META","MSFT"]

  // ── Sizing ────────────────────────────────────────────
  portfolioSize: number;              // total paper account size ($)
  riskPctGradeA: number;             // % of portfolio per Grade A trade (e.g. 3)
  riskPctGradeB: number;             // % of portfolio per Grade B trade (e.g. 2)
  maxContracts: number;              // hard cap on contracts per trade
  maxOpenPositions: number;          // max simultaneous open positions

  // ── Timing (all times in ET "HH:MM") ─────────────────
  activeHoursStart: string;          // e.g. "09:30"
  activeHoursEnd: string;            // e.g. "15:45"
  forceCloseTime: string;            // e.g. "15:45" — close all open positions before this
  cooldownMinutes: number;           // minutes to wait after exit before re-entering same ticker
  maxTradesPerDay: number;           // max entries per calendar day
  dailyLossLimit: number;            // stop trading after this P&L (negative, e.g. -2000)

  // ── Entry Filters ─────────────────────────────────────
  minGrade: "A" | "B";              // minimum option quality grade to trade
  minConfluenceScore: number;        // 0–10, minimum signal confluence
  minWallClass: "WEAK" | "MODERATE" | "STRONG" | "IMPENETRABLE";
  regimeFilter: "positive" | "negative" | "both"; // gamma regime filter

  // ── Exit Rules ────────────────────────────────────────
  exitTrigger: "stock_price" | "option_premium"; // what triggers the exit
  gradeAMinReturnPct: number;        // min % option return for Grade A target (e.g. 50)
  gradeBMinReturnPct: number;        // min % option return for Grade B target (e.g. 20)

  // ── Option Filters ────────────────────────────────────
  minOI: number;                     // minimum open interest
  maxSpreadPct: number;             // max bid-ask spread %
  minVolume: number;                 // minimum option volume
  maxDte: number;                    // max days to expiry (0 = 0-DTE only)
}

// ═══════════════════════════════════════════════════════════
// Support / Resistance Level
// ═══════════════════════════════════════════════════════════

export interface SRLevel {
  price: number;
  type: "SUPPORT" | "RESISTANCE" | "SUPPORT/RESISTANCE";
  source: string;
  classification: string;
  strength: number;
}

// ═══════════════════════════════════════════════════════════
// Full Ticker Result (returned to frontend)
// ═══════════════════════════════════════════════════════════

export interface TickerResult {
  ticker: string;
  timestamp: string;
  spot: number;
  expiration: string;
  dte: number;
  gamma_regime: "POSITIVE_GAMMA" | "NEGATIVE_GAMMA";
  net_gex: number;
  total_dex: number;
  delta_bias: "BULLISH" | "BEARISH" | "NEUTRAL";
  expected_move: number | null;
  walls: Record<string, WallData>;
  volume_profile: VolumeProfile;
  confluence_levels: ConfluenceLevel[];
  scalp_signal: ScalpSignal;
  options_signal: OptionsSignal | null;
  support_resistance: SRLevel[];
  options_chain: OptionRow[];
  signal_ready: boolean;
}

// ═══════════════════════════════════════════════════════════
// API Request / Raw API types
// ═══════════════════════════════════════════════════════════

export interface FetchRequest {
  ticker?: string;
  force?: boolean;
}

export interface BarData {
  o: number;
  h: number;
  l: number;
  c: number;
  v: number;
  t: number;
}
