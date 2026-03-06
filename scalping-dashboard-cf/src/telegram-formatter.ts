// ═══════════════════════════════════════════════════════════
// Telegram Report Formatter — Arabic
// Edit this file to change how the bot report looks.
// ═══════════════════════════════════════════════════════════

import type { TickerResult, WallData, SRLevel, OptionsSignal } from "./types";
import { computeSizing } from "./sizing";

/** Escape special chars for Telegram MarkdownV2 */
function esc(text: string | number | null | undefined): string {
  return String(text ?? "N/A").replace(/([_*\[\]()~`>#\+\-=|{}.!])/g, "\\$1");
}

function fmtPrice(price: number | null | undefined): string {
  if (price == null) return "N/A";
  return `$${price.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function directionEmoji(dir: string): string {
  if (dir === "LONG") return "\u{1F7E2}";
  if (dir === "SHORT") return "\u{1F534}";
  return "\u26AA";
}

function directionAr(dir: string): string {
  if (dir === "LONG") return "\u{1F7E2} شراء";
  if (dir === "SHORT") return "\u{1F534} بيع";
  return "\u26AA لا توجد صفقة";
}

function classificationAr(c: string): string {
  if (c === "IMPENETRABLE") return "غير قابل للاختراق";
  if (c === "STRONG") return "قوي";
  if (c === "MODERATE") return "متوسط";
  if (c === "WEAK") return "ضعيف";
  return c;
}

function strengthAr(s: string): string {
  if (s === "HIGH") return "عالية";
  if (s === "MEDIUM") return "متوسطة";
  if (s === "LOW") return "منخفضة";
  return s;
}

function regimeAr(r: string): string {
  if (r === "POSITIVE_GAMMA") return "جاما إيجابية";
  if (r === "NEGATIVE_GAMMA") return "جاما سلبية";
  return r;
}

function biasAr(b: string): string {
  if (b === "BULLISH") return "صعودي";
  if (b === "BEARISH") return "هبوطي";
  if (b === "NEUTRAL") return "محايد";
  return b;
}

function tradeStyleAr(s: string): string {
  if (s === "FADE") return "عكس الاتجاه";
  if (s === "MOMENTUM") return "مع الاتجاه";
  return s;
}

function priceZoneAr(z: string): string {
  if (z === "AT_CALL_WALL") return "عند جدار الكول";
  if (z === "AT_PUT_WALL") return "عند جدار البوت";
  if (z === "ABOVE_POC") return "فوق نقطة التحكم";
  if (z === "BELOW_POC") return "تحت نقطة التحكم";
  if (z === "AT_POC") return "عند نقطة التحكم";
  return z;
}

function entryTypeAr(e: string): string {
  if (e === "HVN_BOUNCE") return "ارتداد من منطقة سيولة عالية";
  if (e === "WALL_FADE") return "ارتداد من الجدار";
  if (e === "WALL_BREAK") return "كسر الجدار";
  if (e === "POC_BOUNCE") return "ارتداد من نقطة التحكم";
  if (e === "VP_EDGE") return "حافة بروفايل الحجم";
  return e;
}

function srTypeAr(t: string): string {
  if (t === "SUPPORT") return "دعم";
  if (t === "RESISTANCE") return "مقاومة";
  if (t === "SUPPORT/RESISTANCE") return "دعم/مقاومة";
  return t;
}

function gradeAr(g: string): string {
  if (g === "A") return "ممتاز A";
  if (g === "B") return "جيد B";
  if (g === "C") return "مقبول C";
  return g;
}

function contractTypeAr(ct: string): string {
  if (ct === "CALL") return "شراء كول";
  if (ct === "PUT") return "شراء بوت";
  return ct;
}

// ── Walls ────────────────────────────────────────────────
function formatWalls(walls: Record<string, WallData>, limit = 3): string {
  const sorted = Object.values(walls)
    .sort((a, b) => Math.abs(b.gex) - Math.abs(a.gex))
    .slice(0, limit);

  if (sorted.length === 0) return esc("   لا توجد جدران");

  return sorted.map((w) => {
    const gex =
      Math.abs(w.gex) >= 1e6
        ? `${(w.gex / 1e6).toFixed(1)}M`
        : `${(w.gex / 1e3).toFixed(1)}K`;
    const cls = classificationAr(w.classification);
    return `   ${esc("▸")} ${esc(`$${w.strike.toFixed(2)}`)}  ${esc(cls)}  ${esc(`(${gex})`)}`;
  }).join("\n");
}

// ── Support / Resistance ─────────────────────────────────
function formatSR(levels: SRLevel[], limit = 4): string {
  if (!levels || levels.length === 0) return esc("   لا توجد مستويات");

  const sorted = [...levels].sort((a, b) => b.strength - a.strength).slice(0, limit);

  return sorted.map((lv) => {
    const icon = lv.type.includes("SUPPORT") ? "\u{1F7E2}" : "\u{1F534}";
    const typeAr = srTypeAr(lv.type);
    return `   ${icon} ${esc(`$${lv.price.toFixed(2)}`)}  ${esc(typeAr)}`;
  }).join("\n");
}

// ── Separator line ───────────────────────────────────────
const SEP = esc("━━━━━━━━━━━━━━━━━━━━━━━━");

/**
 * Format a TickerResult into a Telegram MarkdownV2 message (Arabic).
 * This is the main function — edit it to change report layout.
 */
export function formatReport(data: TickerResult, portfolioSize?: number): string {
  const signal = data.scalp_signal;
  const dir = signal.direction;
  const emoji = directionEmoji(dir);

  const lines: string[] = [];

  // ══════════════ Header ══════════════
  lines.push(`${emoji} *${esc(data.ticker)}*  ${esc(fmtPrice(data.spot))}`);
  lines.push(`_${esc(data.timestamp)}_`);
  lines.push(SEP);

  // ══════════════ Signal ══════════════
  if (dir === "NO_TRADE") {
    lines.push("");
    lines.push(`\u{26D4} *${esc("لا توجد صفقة حالياً")}*`);
    if (signal.reason) lines.push(`_${esc(signal.reason)}_`);
    lines.push("");
  } else {
    lines.push("");
    lines.push(`\u{1F3AF} *${esc("إشارة التداول")}*`);
    lines.push("");
    lines.push(`*${esc("الاتجاه:")}*  ${esc(directionAr(dir))}`);
    lines.push(`*${esc("الدخول:")}*   ${esc(fmtPrice(signal.entry))}`);
    lines.push(`*${esc("الهدف:")}*    ${esc(fmtPrice(signal.target))}`);
    lines.push(`*${esc("الوقف:")}*    ${esc(fmtPrice(signal.stop))}`);
    lines.push("");
    if (signal.entry_type) {
      lines.push(`*${esc("نوع الدخول:")}*  ${esc(entryTypeAr(signal.entry_type))}`);
    }
    if (signal.trade_style) {
      lines.push(`*${esc("الأسلوب:")}*     ${esc(tradeStyleAr(signal.trade_style))}`);
    }
    if (signal.price_zone) {
      lines.push(`*${esc("المنطقة:")}*     ${esc(priceZoneAr(signal.price_zone))}`);
    }
  }
  lines.push(SEP);

  // ══════════════ Confluence ══════════════
  lines.push("");
  lines.push(`\u{1F4CA} *${esc("تقييم الصفقة")}*`);
  lines.push("");

  const scoreBar = buildScoreBar(signal.confluence_score);
  lines.push(`*${esc("التوافق:")}*  ${scoreBar}  ${esc(`${signal.confluence_score}/10`)}`);
  lines.push(`*${esc("القوة:")}*    ${esc(strengthAr(signal.signal_strength))}`);

  const tradeableIcon = signal.tradeable ? "\u2705" : "\u274C";
  const tradeableText = signal.tradeable ? "قابلة للتداول" : "غير قابلة للتداول";
  lines.push(`*${esc("الحالة:")}*   ${tradeableIcon} ${esc(tradeableText)}`);

  if (signal.fast_move_zone) {
    lines.push(`\u26A1 *${esc("تحذير: منطقة حركة سريعة!")}*`);
  }
  lines.push(SEP);

  // ══════════════ Market Context ══════════════
  lines.push("");
  lines.push(`\u{1F30D} *${esc("سياق السوق")}*`);
  lines.push("");

  const regimeIcon = data.gamma_regime === "POSITIVE_GAMMA" ? "\u{1F6E1}\uFE0F" : "\u{1F525}";
  lines.push(`*${esc("الجاما:")}*       ${regimeIcon} ${esc(regimeAr(data.gamma_regime))}`);
  lines.push(`*${esc("اتجاه الدلتا:")}* ${esc(biasAr(data.delta_bias))}`);
  if (data.expected_move != null) {
    lines.push(`*${esc("الحركة المتوقعة:")}* ${esc(fmtPrice(data.expected_move))}`);
  }
  lines.push(SEP);

  // ══════════════ Volume Profile ══════════════
  const vp = data.volume_profile;
  if (vp.poc != null) {
    lines.push("");
    lines.push(`\u{1F4C8} *${esc("بروفايل الحجم")}*`);
    lines.push("");
    lines.push(`*${esc("نقطة التحكم:")}*    ${esc(fmtPrice(vp.poc))}`);
    lines.push(`*${esc("أعلى منطقة القيمة:")}* ${esc(fmtPrice(vp.value_area_high))}`);
    lines.push(`*${esc("أدنى منطقة القيمة:")}* ${esc(fmtPrice(vp.value_area_low))}`);
    lines.push(SEP);
  }

  // ══════════════ Walls ══════════════
  if (Object.keys(data.walls).length > 0) {
    lines.push("");
    lines.push(`\u{1F9F1} *${esc("جدران الجاما")}*`);
    lines.push("");
    lines.push(formatWalls(data.walls));
    lines.push(SEP);
  }

  // ══════════════ S/R ══════════════
  if (data.support_resistance && data.support_resistance.length > 0) {
    lines.push("");
    lines.push(`\u{1F4CD} *${esc("مستويات الدعم والمقاومة")}*`);
    lines.push("");
    lines.push(formatSR(data.support_resistance));
    lines.push(SEP);
  }

  // ══════════════ Options Signal ══════════════
  const opt = data.options_signal;
  if (opt && opt.contract_type !== "NONE") {
    const optEmoji = opt.contract_type === "CALL" ? "\u{1F7E2}" : "\u{1F534}";
    lines.push("");
    lines.push(`\u{1F4C4} *${esc("إشارة الأوبشن")}*`);
    lines.push("");
    lines.push(`${optEmoji} *${esc(contractTypeAr(opt.contract_type))}*  ${esc(`$${opt.strike % 1 === 0 ? opt.strike.toFixed(0) : opt.strike.toFixed(2)}`)}`);
    lines.push(`*${esc("الانتهاء:")}*  ${esc(opt.expiration)} ${esc(`(${opt.dte}d)`)}`);
    lines.push(`*${esc("التقييم:")}*   ${esc(gradeAr(opt.grade))}`);
    lines.push("");
    lines.push(`*${esc("سعر الدخول:")}*  ${esc(`$${opt.entry_premium.toFixed(2)}`)}`);
    lines.push(`*${esc("سعر الهدف:")}*   ${esc(`$${opt.target_premium.toFixed(2)}`)}`);
    lines.push(`*${esc("سعر الوقف:")}*   ${esc(`$${opt.stop_premium.toFixed(2)}`)}`);
    lines.push("");
    const retSign = opt.expected_return_pct >= 0 ? "+" : "";
    lines.push(`*${esc("العائد المتوقع:")}* ${esc(`${retSign}${opt.expected_return_pct.toFixed(1)}%`)}`);
    lines.push(`*${esc("الحد الأقصى للخسارة:")}* ${esc(`$${opt.max_loss_per_contract.toFixed(0)}`)}`);
    lines.push(`*${esc("نقطة التعادل:")}* ${esc(`$${opt.break_even.toFixed(2)}`)}`);
    lines.push("");
    lines.push(`*${esc("اليونانيات:")}*  \u0394${esc(opt.delta.toFixed(3))}  \u0393${esc(opt.gamma.toFixed(4))}  \u0398${esc(opt.theta.toFixed(3))}`);
    lines.push(`*${esc("التقلب الضمني:")}*  ${esc(`${opt.iv.toFixed(1)}%`)}`);
    lines.push(`*${esc("الحجم / OI:")}*  ${esc(`${opt.volume} / ${opt.open_interest}`)}`);
    lines.push(`*${esc("الفارق:")}*  ${esc(`${opt.bid_ask_spread_pct.toFixed(1)}%`)}`);
    if (opt.reason) {
      lines.push(`_${esc(opt.reason)}_`);
    }

    // ── Position Sizing ──
    if (portfolioSize && portfolioSize > 0) {
      const sizing = computeSizing(portfolioSize, opt, data.scalp_signal);
      if (sizing) {
        lines.push("");
        lines.push(`\u{1F4B0} *${esc("حجم الصفقة")}*`);
        const confAr = sizing.confidence_label === "HIGH" ? "عالية" : sizing.confidence_label === "MEDIUM" ? "متوسطة" : "منخفضة";
        lines.push(`*${esc("الثقة:")}*  ${esc(confAr)} ${esc(`(${(sizing.risk_pct * 100).toFixed(0)}%)`)}`);
        lines.push(`*${esc("العقود:")}*  ${esc(String(sizing.contracts))}`);
        lines.push(`*${esc("التكلفة الإجمالية:")}*  ${esc(`$${sizing.total_cost.toLocaleString("en-US")}`)}`);
        lines.push(`*${esc("المخاطرة:")}*  ${esc(`$${sizing.total_risk.toLocaleString("en-US")}`)} ${esc(`(${sizing.portfolio_risk_pct.toFixed(1)}%)`)}`);
        lines.push(`*${esc("الربح المتوقع:")}*  ${esc(`$${sizing.estimated_profit.toLocaleString("en-US")}`)}`);
      }
    }
    lines.push(SEP);
  }

  // ══════════════ Reason ══════════════
  if (signal.reason && dir !== "NO_TRADE") {
    lines.push("");
    lines.push(`\u{1F4AC} _${esc(signal.reason)}_`);
  }

  lines.push("");
  lines.push(`_${esc("⚡ Scalping Dashboard Bot")}_`);

  return lines.join("\n");
}

/** Build a visual score bar like ████████░░ */
function buildScoreBar(score: number): string {
  const filled = Math.round(score);
  const empty = 10 - filled;
  return esc("\u2588".repeat(filled) + "\u2591".repeat(empty));
}

// ═══════════════════════════════════════════════════════════
// Compact Alert — sent by auto-alert cron
// Quick to read for scalping decisions
// ═══════════════════════════════════════════════════════════

export function formatAlertCompact(data: TickerResult, portfolioSize?: number): string {
  const signal = data.scalp_signal;
  const dir = signal.direction;

  const lines: string[] = [];

  // ── Header ──
  lines.push(`\u{1F6A8} *${esc("إشارة تداول جديدة")}*`);
  lines.push(SEP);
  lines.push("");

  // ── Ticker + Price ──
  lines.push(`${directionEmoji(dir)} *${esc(data.ticker)}*  ${esc(fmtPrice(data.spot))}`);
  lines.push("");

  // ── Direction + Levels ──
  lines.push(`*${esc("الاتجاه:")}*  ${esc(directionAr(dir))}`);
  lines.push(`*${esc("الدخول:")}*   ${esc(fmtPrice(signal.entry))}`);
  lines.push(`*${esc("الهدف:")}*    ${esc(fmtPrice(signal.target))}`);
  lines.push(`*${esc("الوقف:")}*    ${esc(fmtPrice(signal.stop))}`);
  lines.push("");

  // ── Score ──
  const bar = buildScoreBar(signal.confluence_score);
  lines.push(`*${esc("التوافق:")}*  ${bar}  ${esc(`${signal.confluence_score}/10`)}`);
  lines.push(`*${esc("القوة:")}*    ${esc(strengthAr(signal.signal_strength))}`);

  if (signal.entry_type) {
    lines.push(`*${esc("النوع:")}*    ${esc(entryTypeAr(signal.entry_type))}`);
  }

  if (signal.fast_move_zone) {
    lines.push("");
    lines.push(`\u26A1 *${esc("منطقة حركة سريعة!")}*`);
  }

  // ── Options Signal (compact) ──
  const opt = data.options_signal;
  if (opt && opt.contract_type !== "NONE") {
    const optEmoji = opt.contract_type === "CALL" ? "\u{1F7E2}" : "\u{1F534}";
    lines.push("");
    lines.push(`\u{1F4C4} ${optEmoji} *${esc(contractTypeAr(opt.contract_type))}*  ${esc(`$${opt.strike % 1 === 0 ? opt.strike.toFixed(0) : opt.strike.toFixed(2)}`)}  ${esc(`(${opt.dte}d)`)}`);
    const retSign = opt.expected_return_pct >= 0 ? "+" : "";
    lines.push(`   ${esc(`$${opt.entry_premium.toFixed(2)} → $${opt.target_premium.toFixed(2)}`)}  ${esc(`(${retSign}${opt.expected_return_pct.toFixed(0)}%)`)}`);
    if (portfolioSize && portfolioSize > 0) {
      const sizing = computeSizing(portfolioSize, opt, signal);
      if (sizing) {
        lines.push(`   ${esc(`${sizing.contracts} عقود × $${opt.entry_premium.toFixed(2)} = $${sizing.total_cost.toLocaleString("en-US")}`)}`);
      }
    }
  }

  lines.push("");
  lines.push(`_${esc(data.timestamp)}_`);
  lines.push(`_${esc("⚡ Auto Alert")}_`);

  return lines.join("\n");
}
