// ═══════════════════════════════════════════════════════════
// POST /api/telegram — Telegram Webhook Handler
// Receives updates from Telegram, fetches data, sends reports.
// Supports: preset tickers, custom ticker input, subscribe/unsubscribe
// ═══════════════════════════════════════════════════════════

import type { Env } from "../../src/types";
import { formatReport } from "../../src/telegram-formatter";
import {
  tgSend,
  buildTickerKeyboard,
  isValidTicker,
  addSubscriber,
  removeSubscriber,
  escapeMd,
  getPortfolioSize,
  setPortfolioSize,
  getOpenTickers,
  getOpenPosition,
  getClosedTrades,
} from "../../src/telegram-helpers";
import { getBotConfig, setBotConfig } from "../../src/bot-config";

// ── Fetch + Send Report (shared by callback & text input) ─
async function fetchAndSendReport(
  token: string,
  chatId: number,
  ticker: string,
  apiBase: string,
  cache: KVNamespace,
) {
  // Send loading message
  const loadingResp = await tgSend(token, "sendMessage", {
    chat_id: chatId,
    text: `\u23F3 ${ticker} ...`,
  });
  const loadingMsgId = loadingResp.result?.message_id;

  try {
    const fetchResp = await fetch(`${apiBase}/api/fetch`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ticker, force: true }),
    });

    if (!fetchResp.ok) throw new Error(`API ${fetchResp.status}`);
    const data = (await fetchResp.json()) as any;
    if (data.error) throw new Error(data.error);

    const portfolioSize = await getPortfolioSize(cache, chatId);
    const report = formatReport(data, portfolioSize);
    await tgSend(token, "editMessageText", {
      chat_id: chatId,
      message_id: loadingMsgId,
      text: report,
      parse_mode: "MarkdownV2",
    });
  } catch (err: any) {
    await tgSend(token, "editMessageText", {
      chat_id: chatId,
      message_id: loadingMsgId,
      text: `\u274C ${ticker}: ${String(err.message || err).slice(0, 200)}`,
    });
  }

  // Re-show keyboard
  await tgSend(token, "sendMessage", {
    chat_id: chatId,
    text: escapeMd("اختر سهم أو اكتب أي رمز:"),
    parse_mode: "MarkdownV2",
    reply_markup: buildTickerKeyboard(),
  });
}

// ── Start / Welcome ──────────────────────────────────────
async function handleStart(token: string, chatId: number) {
  await tgSend(token, "sendMessage", {
    chat_id: chatId,
    text:
      `\u{1F4CA} *${escapeMd("بوت إشارات السكالبينج")}*\n\n` +
      `${escapeMd("اختر سهم من القائمة أو اكتب أي رمز سهم:")}`,
    parse_mode: "MarkdownV2",
    reply_markup: buildTickerKeyboard(),
  });
}

// ── Webhook entry point ──────────────────────────────────
export const onRequestPost: PagesFunction<Env> = async (context) => {
  const { env, request } = context;
  const token = env.TELEGRAM_BOT_TOKEN;

  if (!token) {
    return Response.json({ error: "TELEGRAM_BOT_TOKEN not configured" }, { status: 500 });
  }

  const update = (await request.json()) as any;
  const apiBase = new URL(request.url).origin;

  try {
    // ── Text messages (commands + custom tickers) ──
    if (update.message?.text) {
      const text = update.message.text.trim();
      const chatId = update.message.chat.id;

      if (text === "/start" || text === "/ticker") {
        // Auto-subscribe on /start
        await addSubscriber(env.SCALPING_CACHE, chatId);
        await handleStart(token, chatId);

      } else if (text === "/subscribe") {
        await addSubscriber(env.SCALPING_CACHE, chatId);
        await tgSend(token, "sendMessage", {
          chat_id: chatId,
          text: `\u2705 ${escapeMd("تم تفعيل التنبيهات التلقائية")}`,
          parse_mode: "MarkdownV2",
        });

      } else if (text === "/unsubscribe") {
        await removeSubscriber(env.SCALPING_CACHE, chatId);
        await tgSend(token, "sendMessage", {
          chat_id: chatId,
          text: `\u274C ${escapeMd("تم إيقاف التنبيهات التلقائية")}`,
          parse_mode: "MarkdownV2",
        });

      } else if (text.startsWith("/portfolio")) {
        const parts = text.split(/\s+/);
        if (parts.length >= 2) {
          const size = parseFloat(parts[1]);
          if (size > 0 && size <= 10_000_000) {
            await setPortfolioSize(env.SCALPING_CACHE, chatId, size);
            await tgSend(token, "sendMessage", {
              chat_id: chatId,
              text: `\u2705 ${escapeMd(`حجم المحفظة: $${size.toLocaleString("en-US")}`)}`,
              parse_mode: "MarkdownV2",
            });
          } else {
            await tgSend(token, "sendMessage", {
              chat_id: chatId,
              text: `\u274C ${escapeMd("أدخل مبلغ صحيح. مثال: /portfolio 25000")}`,
              parse_mode: "MarkdownV2",
            });
          }
        } else {
          const current = await getPortfolioSize(env.SCALPING_CACHE, chatId);
          const msg = current > 0
            ? `\u{1F4B0} ${escapeMd(`حجم المحفظة: $${current.toLocaleString("en-US")}`)}\n${escapeMd("لتغييره: /portfolio 25000")}`
            : `${escapeMd("لم يتم تعيين حجم المحفظة.")}\n${escapeMd("مثال: /portfolio 25000")}`;
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: msg,
            parse_mode: "MarkdownV2",
          });
        }

      } else if (text.startsWith("/bot")) {
        const parts = text.split(/\s+/);
        const action = parts[1]?.toLowerCase();
        if (action === "on") {
          const cfg = await getBotConfig(env.SCALPING_CACHE, "A");
          await setBotConfig(env.SCALPING_CACHE, { ...cfg, enabled: true });
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: `\u2705 ${escapeMd("\u{1F916} بوت التداول: مفعّل")}`,
            parse_mode: "MarkdownV2",
          });
        } else if (action === "off") {
          const cfg = await getBotConfig(env.SCALPING_CACHE, "A");
          await setBotConfig(env.SCALPING_CACHE, { ...cfg, enabled: false });
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: `\u274C ${escapeMd("\u{1F916} بوت التداول: متوقف")}`,
            parse_mode: "MarkdownV2",
          });
        } else {
          const cfg = await getBotConfig(env.SCALPING_CACHE, "A");
          const enabled = cfg.enabled;
          const statusAr = enabled ? "مفعّل \u2705" : "متوقف \u274C";
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: `\u{1F916} ${escapeMd(`بوت التداول: ${statusAr}`)}\n${escapeMd("للتشغيل: /bot on")}\n${escapeMd("للإيقاف: /bot off")}`,
            parse_mode: "MarkdownV2",
          });
        }

      } else if (text === "/positions") {
        const openTickers = await getOpenTickers(env.SCALPING_CACHE);
        if (openTickers.length === 0) {
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: escapeMd("\u{1F4ED} لا توجد صفقات مفتوحة"),
            parse_mode: "MarkdownV2",
          });
        } else {
          const lines: string[] = [];
          lines.push(`*${escapeMd("\u{1F4CA} الصفقات المفتوحة")}*`);
          lines.push("");
          for (const t of openTickers) {
            const pos = await getOpenPosition(env.SCALPING_CACHE, t);
            if (!pos) continue;
            const typeEmoji = pos.contract_type === "CALL" ? "\u{1F7E2}" : "\u{1F534}";
            const strike = pos.strike % 1 === 0 ? pos.strike.toFixed(0) : pos.strike.toFixed(2);
            lines.push(`${typeEmoji} *${escapeMd(pos.ticker)}* ${escapeMd(pos.contract_type)} ${escapeMd(`$${strike}`)}`);
            lines.push(`   ${escapeMd(`${pos.contracts} عقد @ $${pos.entry_premium.toFixed(2)}`)}`);
            const stockTgt = (pos as any).stock_target ? ` | هدف السهم: $${(pos as any).stock_target.toFixed(2)}` : "";
            lines.push(`   ${escapeMd(`هدف الأوبشن: $${pos.target_premium.toFixed(2)}${stockTgt} | وقف: بدون`)}`);
            lines.push("");
          }
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: lines.join("\n"),
            parse_mode: "MarkdownV2",
          });
        }

      } else if (text === "/trades") {
        const trades = await getClosedTrades(env.SCALPING_CACHE, 10);
        if (trades.length === 0) {
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: escapeMd("\u{1F4ED} لا توجد صفقات مغلقة"),
            parse_mode: "MarkdownV2",
          });
        } else {
          const lines: string[] = [];
          lines.push(`*${escapeMd("\u{1F4D6} آخر الصفقات")}*`);
          lines.push("");
          for (const t of trades) {
            const emoji = t.result === "WIN" ? "\u2705" : "\u274C";
            const pnlSign = t.pnl_dollars >= 0 ? "+" : "";
            const strike = t.strike % 1 === 0 ? t.strike.toFixed(0) : t.strike.toFixed(2);
            lines.push(`${emoji} *${escapeMd(t.ticker)}* ${escapeMd(t.contract_type)} ${escapeMd(`$${strike}`)}`);
            lines.push(`   ${escapeMd(`${pnlSign}$${t.pnl_dollars.toFixed(0)} (${pnlSign}${t.pnl_pct.toFixed(1)}%)`)}`);
          }
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: lines.join("\n"),
            parse_mode: "MarkdownV2",
          });
        }

      } else if (text === "/pnl") {
        const trades = await getClosedTrades(env.SCALPING_CACHE, 100);
        if (trades.length === 0) {
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: escapeMd("\u{1F4ED} لا توجد صفقات مغلقة لحساب الأداء"),
            parse_mode: "MarkdownV2",
          });
        } else {
          const totalPnl = trades.reduce((s, t) => s + t.pnl_dollars, 0);
          const wins = trades.filter(t => t.result === "WIN").length;
          const losses = trades.filter(t => t.result !== "WIN").length;
          const winRate = trades.length > 0 ? ((wins / trades.length) * 100).toFixed(0) : "0";
          const avgReturn = trades.length > 0 ? (trades.reduce((s, t) => s + t.pnl_pct, 0) / trades.length).toFixed(1) : "0";
          const openCount = (await getOpenTickers(env.SCALPING_CACHE)).length;
          const pnlSign = totalPnl >= 0 ? "+" : "";
          const pnlEmoji = totalPnl >= 0 ? "\u{1F4B0}" : "\u{1F4C9}";

          const lines: string[] = [];
          lines.push(`*${escapeMd("\u{1F4CA} أداء بوت التداول")}*`);
          lines.push("");
          lines.push(`${pnlEmoji} *${escapeMd("إجمالي الربح/الخسارة:")}* ${escapeMd(`${pnlSign}$${totalPnl.toFixed(0)}`)}`);
          lines.push(`${escapeMd(`\u2705 فوز: ${wins}  |  \u274C خسارة: ${losses}`)}`);
          lines.push(`${escapeMd(`\u{1F3AF} نسبة الفوز: ${winRate}%`)}`);
          lines.push(`${escapeMd(`\u{1F4C8} متوسط العائد: ${avgReturn}%`)}`);
          lines.push(`${escapeMd(`\u{1F4C2} صفقات مفتوحة: ${openCount}`)}`);
          lines.push(`${escapeMd(`\u{1F4CA} إجمالي الصفقات: ${trades.length}`)}`);
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: lines.join("\n"),
            parse_mode: "MarkdownV2",
          });
        }

      } else if (!text.startsWith("/")) {
        // Treat as custom ticker
        const customTicker = text.toUpperCase().replace(/\s/g, "");
        if (isValidTicker(customTicker)) {
          await fetchAndSendReport(token, chatId, customTicker, apiBase, env.SCALPING_CACHE);
        } else {
          await tgSend(token, "sendMessage", {
            chat_id: chatId,
            text: `\u274C ${escapeMd("رمز غير صالح. اكتب رمز السهم (1-5 أحرف) مثل: AAPL")}`,
            parse_mode: "MarkdownV2",
          });
        }
      }
    }

    // ── Callback queries (inline keyboard buttons) ──
    if (update.callback_query) {
      const callbackData = update.callback_query.data as string;
      const chatId = update.callback_query.message.chat.id;
      const callbackQueryId = update.callback_query.id;

      // Answer callback (removes spinner)
      await tgSend(token, "answerCallbackQuery", {
        callback_query_id: callbackQueryId,
      });

      // "Full Report" button from auto-alert
      if (callbackData.startsWith("report:")) {
        const ticker = callbackData.slice(7);
        if (isValidTicker(ticker)) {
          await fetchAndSendReport(token, chatId, ticker, apiBase, env.SCALPING_CACHE);
        }
      }
      // Preset ticker button
      else if (isValidTicker(callbackData)) {
        await fetchAndSendReport(token, chatId, callbackData, apiBase, env.SCALPING_CACHE);
      }
    }
  } catch (err: any) {
    console.error("Telegram webhook error:", err);
  }

  // Always return 200 to Telegram
  return new Response("OK", { status: 200 });
};

// ── GET handler for webhook setup ────────────────────────
export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { env, request } = context;
  const token = env.TELEGRAM_BOT_TOKEN;

  if (!token) {
    return Response.json({ error: "TELEGRAM_BOT_TOKEN not configured" }, { status: 500 });
  }

  const webhookUrl = `${new URL(request.url).origin}/api/telegram`;

  const result = await tgSend(token, "setWebhook", {
    url: webhookUrl,
    drop_pending_updates: true,
  });

  return Response.json({
    message: "Webhook registration",
    webhook_url: webhookUrl,
    telegram_response: result,
  });
};
