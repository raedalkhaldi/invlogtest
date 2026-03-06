"""
Report formatter for Telegram bot — Arabic
Edit this file to change how the analysis report looks in Telegram.
"""

import re


def escape_md(text: str) -> str:
    """Escape special characters for Telegram MarkdownV2."""
    special = r"_*[]()~`>#+-=|{}.!"
    return re.sub(f"([{re.escape(special)}])", r"\\\1", str(text))


def _fmt_price(price) -> str:
    if price is None:
        return "N/A"
    return f"${price:,.2f}"


def _direction_ar(direction: str) -> str:
    if direction == "LONG":
        return "\U0001F7E2 شراء"
    elif direction == "SHORT":
        return "\U0001F534 بيع"
    return "\u26AA لا توجد صفقة"


def _direction_emoji(direction: str) -> str:
    if direction == "LONG":
        return "\U0001F7E2"
    elif direction == "SHORT":
        return "\U0001F534"
    return "\u26AA"


def _classification_ar(c: str) -> str:
    return {
        "IMPENETRABLE": "غير قابل للاختراق",
        "STRONG": "قوي",
        "MODERATE": "متوسط",
        "WEAK": "ضعيف",
    }.get(c, c)


def _strength_ar(s: str) -> str:
    return {"HIGH": "عالية", "MEDIUM": "متوسطة", "LOW": "منخفضة"}.get(s, s)


def _regime_ar(r: str) -> str:
    return {
        "POSITIVE_GAMMA": "جاما إيجابية",
        "NEGATIVE_GAMMA": "جاما سلبية",
    }.get(r, r)


def _bias_ar(b: str) -> str:
    return {"BULLISH": "صعودي", "BEARISH": "هبوطي", "NEUTRAL": "محايد"}.get(b, b)


def _trade_style_ar(s: str) -> str:
    return {"FADE": "عكس الاتجاه", "MOMENTUM": "مع الاتجاه"}.get(s, s)


def _price_zone_ar(z: str) -> str:
    return {
        "AT_CALL_WALL": "عند جدار الكول",
        "AT_PUT_WALL": "عند جدار البوت",
        "ABOVE_POC": "فوق نقطة التحكم",
        "BELOW_POC": "تحت نقطة التحكم",
        "AT_POC": "عند نقطة التحكم",
    }.get(z, z)


def _entry_type_ar(e: str) -> str:
    return {
        "HVN_BOUNCE": "ارتداد من منطقة سيولة عالية",
        "WALL_FADE": "ارتداد من الجدار",
        "WALL_BREAK": "كسر الجدار",
        "POC_BOUNCE": "ارتداد من نقطة التحكم",
        "VP_EDGE": "حافة بروفايل الحجم",
    }.get(e, e)


def _sr_type_ar(t: str) -> str:
    return {
        "SUPPORT": "دعم",
        "RESISTANCE": "مقاومة",
        "SUPPORT/RESISTANCE": "دعم/مقاومة",
    }.get(t, t)


def _score_bar(score: int) -> str:
    filled = min(max(round(score), 0), 10)
    empty = 10 - filled
    return "\u2588" * filled + "\u2591" * empty


SEP = escape_md("━" * 24)


# ── Walls ─────────────────────────────────────────────────
def _format_walls(walls: dict, limit: int = 3) -> str:
    if not walls:
        return escape_md("   لا توجد جدران")

    sorted_walls = sorted(
        walls.values(),
        key=lambda w: abs(w.get("gex", 0)),
        reverse=True,
    )[:limit]

    lines = []
    for w in sorted_walls:
        strike = w.get("strike", 0)
        gex = w.get("gex", 0)
        gex_display = f"{gex / 1e6:.1f}M" if abs(gex) >= 1e6 else f"{gex / 1e3:.1f}K"
        cls = _classification_ar(w.get("classification", "?"))
        lines.append(
            f"   {escape_md('▸')} {escape_md(f'${strike:,.2f}')}  {escape_md(cls)}  {escape_md(f'({gex_display})')}"
        )
    return "\n".join(lines)


# ── Support / Resistance ─────────────────────────────────
def _format_sr(levels: list, limit: int = 4) -> str:
    if not levels:
        return escape_md("   لا توجد مستويات")

    sorted_levels = sorted(
        levels, key=lambda l: l.get("strength", 0), reverse=True
    )[:limit]

    lines = []
    for lv in sorted_levels:
        price = lv.get("price", 0)
        sr_type = lv.get("type", "?")
        icon = "\U0001F7E2" if "SUPPORT" in sr_type else "\U0001F534"
        type_ar = _sr_type_ar(sr_type)
        lines.append(
            f"   {icon} {escape_md(f'${price:,.2f}')}  {escape_md(type_ar)}"
        )
    return "\n".join(lines)


def format_report(data: dict) -> str:
    """
    Format the API response into an Arabic Telegram MarkdownV2 message.
    This is the main function to edit when changing report layout.
    """
    ticker = data.get("ticker", "???")
    spot = data.get("spot", 0)
    timestamp = data.get("timestamp", "")
    signal = data.get("scalp_signal", {})
    walls = data.get("walls", {})
    sr_levels = data.get("support_resistance", [])
    vp = data.get("volume_profile", {})

    direction = signal.get("direction", "NO_TRADE")
    emoji = _direction_emoji(direction)

    lines = []

    # ══════════════ Header ══════════════
    lines.append(f"{emoji} *{escape_md(ticker)}*  {escape_md(_fmt_price(spot))}")
    lines.append(f"_{escape_md(timestamp)}_")
    lines.append(SEP)

    # ══════════════ Signal ══════════════
    if direction == "NO_TRADE":
        lines.append("")
        lines.append(f"\u26D4 *{escape_md('لا توجد صفقة حالياً')}*")
        reason = signal.get("reason", "")
        if reason:
            lines.append(f"_{escape_md(reason)}_")
        lines.append("")
    else:
        entry = signal.get("entry")
        target = signal.get("target")
        stop = signal.get("stop")

        lines.append("")
        lines.append(f"\U0001F3AF *{escape_md('إشارة التداول')}*")
        lines.append("")
        lines.append(f"*{escape_md('الاتجاه:')}*  {escape_md(_direction_ar(direction))}")
        lines.append(f"*{escape_md('الدخول:')}*   {escape_md(_fmt_price(entry))}")
        lines.append(f"*{escape_md('الهدف:')}*    {escape_md(_fmt_price(target))}")
        lines.append(f"*{escape_md('الوقف:')}*    {escape_md(_fmt_price(stop))}")
        lines.append("")

        entry_type = signal.get("entry_type", "")
        trade_style = signal.get("trade_style", "")
        price_zone = signal.get("price_zone", "")
        if entry_type:
            lines.append(
                f"*{escape_md('نوع الدخول:')}*  {escape_md(_entry_type_ar(entry_type))}"
            )
        if trade_style:
            lines.append(
                f"*{escape_md('الأسلوب:')}*     {escape_md(_trade_style_ar(trade_style))}"
            )
        if price_zone:
            lines.append(
                f"*{escape_md('المنطقة:')}*     {escape_md(_price_zone_ar(price_zone))}"
            )

    lines.append(SEP)

    # ══════════════ Confluence ══════════════
    confluence = signal.get("confluence_score", 0)
    strength = signal.get("signal_strength", "N/A")
    tradeable = signal.get("tradeable", False)
    fast_move = signal.get("fast_move_zone", False)

    lines.append("")
    lines.append(f"\U0001F4CA *{escape_md('تقييم الصفقة')}*")
    lines.append("")

    bar = escape_md(_score_bar(confluence))
    lines.append(f"*{escape_md('التوافق:')}*  {bar}  {escape_md(f'{confluence}/10')}")
    lines.append(f"*{escape_md('القوة:')}*    {escape_md(_strength_ar(strength))}")

    tradeable_icon = "\u2705" if tradeable else "\u274C"
    tradeable_text = "قابلة للتداول" if tradeable else "غير قابلة للتداول"
    lines.append(f"*{escape_md('الحالة:')}*   {tradeable_icon} {escape_md(tradeable_text)}")

    if fast_move:
        lines.append(f"\u26A1 *{escape_md('تحذير: منطقة حركة سريعة!')}*")

    lines.append(SEP)

    # ══════════════ Market Context ══════════════
    regime = data.get("gamma_regime", "")
    delta_bias = data.get("delta_bias", "")
    expected_move = data.get("expected_move")

    lines.append("")
    lines.append(f"\U0001F30D *{escape_md('سياق السوق')}*")
    lines.append("")

    regime_icon = "\U0001F6E1\uFE0F" if regime == "POSITIVE_GAMMA" else "\U0001F525"
    lines.append(f"*{escape_md('الجاما:')}*       {regime_icon} {escape_md(_regime_ar(regime))}")
    lines.append(f"*{escape_md('اتجاه الدلتا:')}* {escape_md(_bias_ar(delta_bias))}")
    if expected_move is not None:
        lines.append(
            f"*{escape_md('الحركة المتوقعة:')}* {escape_md(f'${expected_move:,.2f}')}"
        )

    lines.append(SEP)

    # ══════════════ Volume Profile ══════════════
    poc = vp.get("poc")
    vah = vp.get("value_area_high")
    val_ = vp.get("value_area_low")
    if poc is not None:
        lines.append("")
        lines.append(f"\U0001F4C8 *{escape_md('بروفايل الحجم')}*")
        lines.append("")
        lines.append(f"*{escape_md('نقطة التحكم:')}*    {escape_md(_fmt_price(poc))}")
        lines.append(f"*{escape_md('أعلى منطقة القيمة:')}* {escape_md(_fmt_price(vah))}")
        lines.append(f"*{escape_md('أدنى منطقة القيمة:')}* {escape_md(_fmt_price(val_))}")
        lines.append(SEP)

    # ══════════════ Walls ══════════════
    if walls:
        lines.append("")
        lines.append(f"\U0001F9F1 *{escape_md('جدران الجاما')}*")
        lines.append("")
        lines.append(_format_walls(walls))
        lines.append(SEP)

    # ══════════════ S/R ══════════════
    if sr_levels:
        lines.append("")
        lines.append(f"\U0001F4CD *{escape_md('مستويات الدعم والمقاومة')}*")
        lines.append("")
        lines.append(_format_sr(sr_levels))
        lines.append(SEP)

    # ══════════════ Reason ══════════════
    reason = signal.get("reason", "")
    if reason and direction != "NO_TRADE":
        lines.append("")
        lines.append(f"\U0001F4AC _{escape_md(reason)}_")

    lines.append("")
    lines.append(f"_{escape_md('⚡ Scalping Dashboard Bot')}_")

    return "\n".join(lines)
