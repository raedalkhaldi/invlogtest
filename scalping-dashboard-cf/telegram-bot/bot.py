"""
Telegram bot for scalping signal reports.
Calls the Scalping Dashboard API and returns formatted analysis.

Usage:
    export TELEGRAM_BOT_TOKEN=<your-bot-token>
    python bot.py
"""

import os
import logging

import httpx
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import (
    ApplicationBuilder,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
)

from formatter import format_report

# ── Config ────────────────────────────────────────────────
API_URL = "https://scalping-dashboard.pages.dev/api/fetch"
API_TIMEOUT = 30  # seconds

TICKERS = [
    "SPY", "QQQ",
    "NVDA", "TSLA",
    "AAPL", "AMZN",
    "META", "MSFT",
    "GOOG", "AMD",
]

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)


# ── Keyboard ──────────────────────────────────────────────
def build_ticker_keyboard() -> InlineKeyboardMarkup:
    """Build inline keyboard with tickers in 2-column rows."""
    buttons = [InlineKeyboardButton(t, callback_data=t) for t in TICKERS]
    rows = [buttons[i : i + 2] for i in range(0, len(buttons), 2)]
    return InlineKeyboardMarkup(rows)


# ── Handlers ──────────────────────────────────────────────
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /start — show welcome message with ticker keyboard."""
    await update.message.reply_text(
        "\U0001F4CA *Scalping Signal Bot*\n\n"
        "Select a ticker to get the latest analysis:",
        reply_markup=build_ticker_keyboard(),
        parse_mode="MarkdownV2",
    )


async def ticker_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /ticker — re-show the ticker keyboard."""
    await update.message.reply_text(
        "Select a ticker:",
        reply_markup=build_ticker_keyboard(),
    )


async def ticker_callback(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle ticker button press — fetch data and send report."""
    query = update.callback_query
    await query.answer()

    ticker = query.data
    if ticker not in TICKERS:
        await query.edit_message_text("Invalid ticker.")
        return

    # Show loading state
    loading_msg = await query.message.reply_text(
        f"\u23F3 Fetching {ticker} analysis..."
    )

    try:
        async with httpx.AsyncClient(timeout=API_TIMEOUT) as client:
            resp = await client.post(
                API_URL,
                json={"ticker": ticker},
            )
            resp.raise_for_status()
            data = resp.json()

        if "error" in data:
            await loading_msg.edit_text(f"\u274C Error: {data['error']}")
            return

        report = format_report(data)
        await loading_msg.edit_text(report, parse_mode="MarkdownV2")

    except httpx.TimeoutException:
        await loading_msg.edit_text(
            f"\u274C Timeout fetching {ticker}. Try again later."
        )
    except Exception as e:
        logger.error("Error fetching %s: %s", ticker, e)
        await loading_msg.edit_text(
            f"\u274C Failed to fetch {ticker}: {str(e)[:200]}"
        )

    # Re-show keyboard for next selection
    await query.message.reply_text(
        "Select another ticker:",
        reply_markup=build_ticker_keyboard(),
    )


# ── Main ──────────────────────────────────────────────────
def main() -> None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    if not token:
        raise SystemExit("Set TELEGRAM_BOT_TOKEN environment variable")

    app = ApplicationBuilder().token(token).build()

    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("ticker", ticker_command))
    app.add_handler(CallbackQueryHandler(ticker_callback))

    logger.info("Bot started. Polling...")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
