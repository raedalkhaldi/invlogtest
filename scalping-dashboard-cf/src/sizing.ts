// ═══════════════════════════════════════════════════════════
// Position Sizing — "Size to Zero"
// For bought options, max loss = entire premium.
// Size based on how much you're willing to lose per trade.
// Max 3% of portfolio per trade, scaled by confidence.
//
// NOTE: This logic is duplicated inline in public/index.html.
// Keep both in sync when making changes.
// ═══════════════════════════════════════════════════════════

import type { OptionsSignal, ScalpSignal, BotConfig } from "./types";

export interface SizingResult {
  /** Confidence tier: 1 = low, 2 = medium, 3 = high */
  confidence_tier: 1 | 2 | 3;
  /** Label for the tier */
  confidence_label: "HIGH" | "MEDIUM" | "LOW";
  /** Risk percentage applied (0.01, 0.02, or 0.03) */
  risk_pct: number;
  /** Dollar amount willing to risk on this trade */
  max_dollar_risk: number;
  /** Cost per contract (entry_premium * 100) */
  cost_per_contract: number;
  /** Number of contracts to buy */
  contracts: number;
  /** Total capital deployed */
  total_cost: number;
  /** Total risk = total_cost (for bought options, cost IS the max loss) */
  total_risk: number;
  /** Percentage of portfolio at risk */
  portfolio_risk_pct: number;
  /** Estimated profit if target hit */
  estimated_profit: number;
  /** Estimated return on risk */
  estimated_return_pct: number;
}

/**
 * Determine confidence-based risk percentage.
 *
 * Tier 3 (HIGH): Grade A + confluence >= 8 + HIGH strength → riskPctGradeA
 * Tier 2 (MEDIUM): everything else                         → riskPctGradeB
 * Tier 1 (LOW): Grade C OR confluence <= 5 OR LOW strength → riskPctGradeB / 2
 */
export function getConfidenceTier(
  grade: OptionsSignal["grade"],
  confluenceScore: number,
  signalStrength: ScalpSignal["signal_strength"],
  riskPctGradeA = 3,
  riskPctGradeB = 2,
): { tier: 1 | 2 | 3; label: "HIGH" | "MEDIUM" | "LOW"; riskPct: number } {
  if (grade === "A" && confluenceScore >= 8 && signalStrength === "HIGH") {
    return { tier: 3, label: "HIGH", riskPct: riskPctGradeA / 100 };
  }
  if (grade === "C" || confluenceScore <= 5 || signalStrength === "LOW") {
    return { tier: 1, label: "LOW", riskPct: Math.max(riskPctGradeB / 2, 1) / 100 };
  }
  return { tier: 2, label: "MEDIUM", riskPct: riskPctGradeB / 100 };
}

/**
 * Compute position sizing for a "size to zero" options trade.
 * Optionally pass a BotConfig to use configured risk percentages and contract caps.
 * Returns null if sizing is not possible.
 */
export function computeSizing(
  portfolioSize: number,
  optionsSignal: OptionsSignal,
  scalpSignal: ScalpSignal,
  config?: Pick<BotConfig, "riskPctGradeA" | "riskPctGradeB" | "maxContracts">,
): SizingResult | null {
  if (portfolioSize <= 0) return null;
  if (optionsSignal.contract_type === "NONE") return null;

  const riskA = config?.riskPctGradeA ?? 3;
  const riskB = config?.riskPctGradeB ?? 2;
  const maxCap = config?.maxContracts ?? 9999;

  const { tier, label, riskPct } = getConfidenceTier(
    optionsSignal.grade,
    scalpSignal.confluence_score,
    scalpSignal.signal_strength,
    riskA,
    riskB,
  );

  const maxDollarRisk = portfolioSize * riskPct;
  const costPerContract = optionsSignal.max_loss_per_contract;

  if (costPerContract <= 0) return null;

  const contracts = Math.min(Math.floor(maxDollarRisk / costPerContract), maxCap);

  if (contracts <= 0) return null;

  const totalCost = contracts * costPerContract;
  const totalRisk = totalCost;
  const portfolioRiskPct = (totalRisk / portfolioSize) * 100;

  const profitPerContract =
    (optionsSignal.target_premium - optionsSignal.entry_premium) * 100;
  const estimatedProfit = contracts * profitPerContract;
  const estimatedReturnPct =
    totalRisk > 0 ? (estimatedProfit / totalRisk) * 100 : 0;

  const r2 = (n: number) => Math.round(n * 100) / 100;

  return {
    confidence_tier: tier,
    confidence_label: label,
    risk_pct: riskPct,
    max_dollar_risk: r2(maxDollarRisk),
    cost_per_contract: r2(costPerContract),
    contracts,
    total_cost: r2(totalCost),
    total_risk: r2(totalRisk),
    portfolio_risk_pct: r2(portfolioRiskPct),
    estimated_profit: r2(estimatedProfit),
    estimated_return_pct: r2(estimatedReturnPct),
  };
}
