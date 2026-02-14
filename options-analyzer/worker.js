/**
 * Options Intelligence Hub - Combined Cloudflare Worker
 * Serves both the frontend HTML and the API endpoints.
 * Uses CBOE (Chicago Board Options Exchange) delayed quotes API.
 * No API key required. Returns real Greeks (delta, gamma, vega, theta).
 * Calculates: GEX, Max Pain, Delta Walls, Volume Profile, Biggest OI Strikes, Expected Range.
 */

// ─── Embedded Frontend HTML ──────────────────────────────────────────────────
const HTML_PAGE = `<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Options Intelligence Hub</title>
<style>
/* ─── CSS Variables & Theme ────────────────────────────────────────────── */
:root {
  --bg: #f5f7fa;
  --bg-card: #ffffff;
  --bg-card-hover: #fafbfc;
  --bg-input: #ffffff;
  --text: #1a1a2e;
  --text-secondary: #6b7280;
  --text-muted: #9ca3af;
  --border: #e5e7eb;
  --border-focus: #3b82f6;
  --shadow: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06);
  --shadow-lg: 0 4px 12px rgba(0,0,0,0.1), 0 2px 4px rgba(0,0,0,0.06);
  --shadow-xl: 0 8px 24px rgba(0,0,0,0.12);
  --primary: #3b82f6;
  --primary-dark: #2563eb;
  --gradient: linear-gradient(135deg, #1e3c72, #2a5298);
  --max-pain: #f59e0b;
  --call-wall: #ef4444;
  --put-wall: #22c55e;
  --gex: #a855f7;
  --volume-poc: #3b82f6;
  --oi-wall: #f97316;
  --success: #22c55e;
  --danger: #ef4444;
  --radius: 12px;
  --radius-sm: 8px;
  --radius-xs: 6px;
  --transition: 200ms ease;
  --font-mono: 'SF Mono', 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

[data-theme="dark"] {
  --bg: #0f1117;
  --bg-card: #1a1d2e;
  --bg-card-hover: #222540;
  --bg-input: #252845;
  --text: #e5e7eb;
  --text-secondary: #9ca3af;
  --text-muted: #6b7280;
  --border: #2d3148;
  --border-focus: #3b82f6;
  --shadow: 0 1px 3px rgba(0,0,0,0.3);
  --shadow-lg: 0 4px 12px rgba(0,0,0,0.4);
  --shadow-xl: 0 8px 24px rgba(0,0,0,0.5);
}

/* ─── Reset & Base ─────────────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--font-sans);
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
  -webkit-font-smoothing: antialiased;
}

/* ─── Header ───────────────────────────────────────────────────────────── */
.header {
  background: var(--gradient);
  color: white;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}

.header-left { display: flex; align-items: center; gap: 12px; }
.header h1 { font-size: 20px; font-weight: 700; letter-spacing: -0.3px; }
.header-badge {
  background: rgba(255,255,255,0.15);
  padding: 2px 10px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.5px;
}

.header-right { display: flex; align-items: center; gap: 12px; }

.theme-toggle {
  background: rgba(255,255,255,0.15);
  border: 1px solid rgba(255,255,255,0.2);
  color: white;
  padding: 6px 12px;
  border-radius: 20px;
  cursor: pointer;
  font-size: 14px;
  transition: background var(--transition);
}
.theme-toggle:hover { background: rgba(255,255,255,0.25); }

/* ─── Main Container ───────────────────────────────────────────────────── */
.container {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px;
}

/* ─── Input Section ────────────────────────────────────────────────────── */
.input-section {
  background: var(--bg-card);
  border-radius: var(--radius);
  padding: 24px;
  margin-bottom: 24px;
  box-shadow: var(--shadow);
  border: 1px solid var(--border);
}

.input-row {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.ticker-input {
  flex: 1;
  min-width: 200px;
  padding: 12px 16px;
  font-size: 16px;
  font-weight: 600;
  text-transform: uppercase;
  border: 2px solid var(--border);
  border-radius: var(--radius-sm);
  background: var(--bg-input);
  color: var(--text);
  transition: border-color var(--transition);
  outline: none;
}
.ticker-input:focus { border-color: var(--border-focus); }
.ticker-input::placeholder { text-transform: none; font-weight: 400; color: var(--text-muted); }

.bulk-input {
  width: 100%;
  padding: 10px 16px;
  font-size: 14px;
  border: 2px solid var(--border);
  border-radius: var(--radius-sm);
  background: var(--bg-input);
  color: var(--text);
  resize: vertical;
  min-height: 40px;
  outline: none;
  font-family: var(--font-sans);
}
.bulk-input:focus { border-color: var(--border-focus); }

.btn {
  padding: 12px 24px;
  border: none;
  border-radius: var(--radius-sm);
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition);
  display: inline-flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
}

.btn-primary {
  background: var(--gradient);
  color: white;
  box-shadow: 0 2px 8px rgba(30,60,114,0.3);
}
.btn-primary:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(30,60,114,0.4); }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }

.btn-sm {
  padding: 6px 14px;
  font-size: 13px;
  border-radius: var(--radius-xs);
}

.btn-outline {
  background: transparent;
  border: 1.5px solid var(--border);
  color: var(--text);
}
.btn-outline:hover { background: var(--bg-card-hover); border-color: var(--primary); color: var(--primary); }

/* ─── Presets ──────────────────────────────────────────────────────────── */
.presets-row {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 16px;
}

.preset-btn {
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 500;
  border: 1.5px solid var(--border);
  border-radius: 20px;
  background: var(--bg-input);
  color: var(--text-secondary);
  cursor: pointer;
  transition: all var(--transition);
}
.preset-btn:hover { border-color: var(--primary); color: var(--primary); background: var(--bg-card-hover); }

/* ─── Progress Bar ─────────────────────────────────────────────────────── */
.progress-container {
  display: none;
  margin-top: 16px;
}
.progress-container.active { display: block; }

.progress-bar-track {
  background: var(--border);
  border-radius: 4px;
  height: 6px;
  overflow: hidden;
}
.progress-bar-fill {
  background: var(--gradient);
  height: 100%;
  border-radius: 4px;
  transition: width 300ms ease;
  width: 0%;
}
.progress-text {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 6px;
  display: flex;
  justify-content: space-between;
}

/* ─── Results Grid ─────────────────────────────────────────────────────── */
.results-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
  gap: 20px;
}

/* ─── Stock Card ───────────────────────────────────────────────────────── */
.stock-card {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  box-shadow: var(--shadow);
  overflow: hidden;
  transition: box-shadow var(--transition), transform var(--transition);
}
.stock-card:hover { box-shadow: var(--shadow-lg); transform: translateY(-2px); }

.card-header {
  padding: 16px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border);
  background: var(--bg-card-hover);
}

.card-symbol { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
.card-price-group { text-align: right; }
.card-price { font-size: 20px; font-weight: 700; font-family: var(--font-mono); }
.card-change { font-size: 13px; font-weight: 600; font-family: var(--font-mono); }
.card-change.up { color: var(--success); }
.card-change.down { color: var(--danger); }

.card-body { padding: 16px 20px; }

/* ─── Price Ladder Visual ──────────────────────────────────────────────── */
.price-ladder {
  position: relative;
  height: 160px;
  margin: 12px 0 20px;
  background: var(--bg);
  border-radius: var(--radius-sm);
  border: 1px solid var(--border);
  overflow: hidden;
}

.ladder-bar {
  position: absolute;
  top: 50%;
  left: 40px;
  right: 40px;
  height: 4px;
  background: var(--border);
  transform: translateY(-50%);
}

.ladder-marker {
  position: absolute;
  transform: translate(-50%, -50%);
  top: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  z-index: 2;
  cursor: default;
}

.ladder-dot {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 1px 4px rgba(0,0,0,0.3);
}

.ladder-label {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.3px;
  white-space: nowrap;
  padding: 1px 4px;
  border-radius: 3px;
  background: var(--bg-card);
}

.ladder-price-label {
  font-size: 10px;
  font-weight: 600;
  font-family: var(--font-mono);
  white-space: nowrap;
  color: var(--text-secondary);
}

.ladder-marker.above .ladder-label { position: absolute; bottom: calc(100% + 2px); }
.ladder-marker.above .ladder-price-label { position: absolute; bottom: calc(100% + 16px); }
.ladder-marker.below .ladder-label { position: absolute; top: calc(100% + 2px); }
.ladder-marker.below .ladder-price-label { position: absolute; top: calc(100% + 16px); }

.ladder-current {
  position: absolute;
  top: 10px;
  bottom: 10px;
  width: 2px;
  background: var(--text);
  transform: translateX(-50%);
  z-index: 3;
}
.ladder-current::after {
  content: attr(data-price);
  position: absolute;
  top: -2px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--text);
  color: var(--bg-card);
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 10px;
  font-weight: 700;
  font-family: var(--font-mono);
  white-space: nowrap;
}

/* ─── Levels Grid ──────────────────────────────────────────────────────── */
.levels-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.level-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: var(--radius-xs);
  background: var(--bg);
  border: 1px solid var(--border);
  transition: background var(--transition);
}
.level-item:hover { background: var(--bg-card-hover); }

.level-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.level-info { flex: 1; min-width: 0; }
.level-label { font-size: 11px; color: var(--text-secondary); font-weight: 500; }
.level-value { font-size: 14px; font-weight: 700; font-family: var(--font-mono); }
.level-pct { font-size: 11px; color: var(--text-muted); font-family: var(--font-mono); }

/* ─── Top Strikes Section ──────────────────────────────────────────────── */
.top-strikes {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.section-title {
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.8px;
  color: var(--text-secondary);
  margin-bottom: 10px;
}

.strike-bar-container { margin-bottom: 6px; }

.strike-bar-header {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  margin-bottom: 2px;
}
.strike-bar-label { font-weight: 600; font-family: var(--font-mono); }
.strike-bar-value { color: var(--text-secondary); font-family: var(--font-mono); }

.strike-bar-track {
  height: 6px;
  background: var(--border);
  border-radius: 3px;
  overflow: hidden;
}
.strike-bar-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 500ms ease;
}

/* ─── Export Section ───────────────────────────────────────────────────── */
.card-export {
  padding: 12px 20px 16px;
  border-top: 1px solid var(--border);
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.export-btn {
  padding: 5px 12px;
  font-size: 11px;
  font-weight: 600;
  border: 1.5px solid var(--border);
  border-radius: var(--radius-xs);
  background: var(--bg);
  color: var(--text-secondary);
  cursor: pointer;
  transition: all var(--transition);
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.export-btn:hover { border-color: var(--primary); color: var(--primary); }

/* ─── TradingView Export Panel ─────────────────────────────────────────── */
.tv-export-section {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  box-shadow: var(--shadow);
  padding: 24px;
  margin-top: 24px;
  display: none;
}
.tv-export-section.active { display: block; }

.tv-export-section h2 {
  font-size: 18px;
  font-weight: 700;
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.tv-export-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.tv-code-block {
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: 12px;
  font-family: var(--font-mono);
  font-size: 12px;
  line-height: 1.5;
  max-height: 300px;
  overflow: auto;
  white-space: pre;
  color: var(--text);
}

.tv-btn-row {
  display: flex;
  gap: 8px;
  margin-top: 12px;
  flex-wrap: wrap;
}

/* ─── Watchlist ────────────────────────────────────────────────────────── */
.watchlist-section {
  margin-bottom: 16px;
}

.watchlist-row {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
}

.watchlist-chip {
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 600;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 16px;
  cursor: pointer;
  transition: all var(--transition);
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.watchlist-chip:hover { border-color: var(--primary); color: var(--primary); }
.watchlist-chip .remove { font-size: 14px; cursor: pointer; opacity: 0.5; }
.watchlist-chip .remove:hover { opacity: 1; color: var(--danger); }

/* ─── Tooltip ──────────────────────────────────────────────────────────── */
.tooltip-trigger { position: relative; cursor: help; }
.tooltip-trigger .tooltip-text {
  display: none;
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translateX(-50%);
  background: var(--text);
  color: var(--bg-card);
  padding: 8px 12px;
  border-radius: var(--radius-xs);
  font-size: 12px;
  font-weight: 400;
  line-height: 1.4;
  white-space: normal;
  width: 220px;
  z-index: 50;
  box-shadow: var(--shadow-lg);
}
.tooltip-trigger:hover .tooltip-text { display: block; }

/* ─── Toast ────────────────────────────────────────────────────────────── */
.toast {
  position: fixed;
  bottom: 24px;
  right: 24px;
  background: var(--text);
  color: var(--bg-card);
  padding: 10px 20px;
  border-radius: var(--radius-sm);
  font-size: 14px;
  font-weight: 500;
  box-shadow: var(--shadow-xl);
  z-index: 1000;
  transform: translateY(100px);
  opacity: 0;
  transition: all 300ms ease;
}
.toast.show { transform: translateY(0); opacity: 1; }

/* ─── Error State ──────────────────────────────────────────────────────── */
.error-card {
  background: var(--bg-card);
  border: 1px solid var(--danger);
  border-radius: var(--radius);
  padding: 20px;
}
.error-card h3 { color: var(--danger); font-size: 16px; margin-bottom: 4px; }
.error-card p { color: var(--text-secondary); font-size: 14px; }

/* ─── Skeleton Loading ─────────────────────────────────────────────────── */
.skeleton-card {
  background: var(--bg-card);
  border-radius: var(--radius);
  border: 1px solid var(--border);
  padding: 20px;
  min-height: 300px;
}
.skeleton-line {
  height: 14px;
  background: linear-gradient(90deg, var(--border) 25%, var(--bg) 50%, var(--border) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 4px;
  margin-bottom: 10px;
}
.skeleton-line.w60 { width: 60%; }
.skeleton-line.w80 { width: 80%; }
.skeleton-line.w40 { width: 40%; }
.skeleton-line.h24 { height: 24px; }

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

/* ─── Responsive ───────────────────────────────────────────────────────── */
@media (max-width: 768px) {
  .container { padding: 12px; }
  .header h1 { font-size: 16px; }
  .header-badge { display: none; }
  .results-grid { grid-template-columns: 1fr; }
  .levels-grid { grid-template-columns: 1fr; }
  .tv-export-grid { grid-template-columns: 1fr; }
  .input-row { flex-direction: column; }
  .ticker-input { min-width: 100%; }
}

@media (max-width: 480px) {
  .header { padding: 12px 16px; }
  .input-section { padding: 16px; }
  .card-body { padding: 12px 16px; }
}

/* ─── Accessibility ────────────────────────────────────────────────────── */
:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* ─── Scrollbar ────────────────────────────────────────────────────────── */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }
</style>
</head>
<body>

<!-- ─── Header ─────────────────────────────────────────────────────────── -->
<header class="header" role="banner">
  <div class="header-left">
    <h1>Options Intelligence Hub</h1>
    <span class="header-badge">BETA</span>
  </div>
  <div class="header-right">
    <span id="dataFreshness" style="font-size:12px;opacity:0.8"></span>
    <button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle dark mode" title="Toggle dark mode">
      <span id="themeIcon">&#9790;</span>
    </button>
  </div>
</header>

<!-- ─── Main Content ───────────────────────────────────────────────────── -->
<main class="container" role="main">

  <!-- Input Section -->
  <section class="input-section" aria-label="Stock input">
    <div class="input-row">
      <input type="text" id="tickerInput" class="ticker-input" placeholder="Enter ticker (e.g., TSLA)"
             aria-label="Stock ticker" maxlength="10"
             onkeydown="if(event.key==='Enter')analyzeStocks()">
      <button class="btn btn-primary" id="analyzeBtn" onclick="analyzeStocks()" aria-label="Analyze stock options">
        Calculate Levels
      </button>
    </div>

    <div style="margin-bottom:12px">
      <textarea id="bulkInput" class="bulk-input" rows="1"
                placeholder="Bulk: TSLA, NVDA, AAPL, MSFT (comma-separated)"
                aria-label="Bulk ticker input"></textarea>
    </div>

    <!-- Preset Groups -->
    <div class="presets-row" role="group" aria-label="Preset stock groups">
      <button class="preset-btn" onclick="loadPreset('tech')">Tech Giants</button>
      <button class="preset-btn" onclick="loadPreset('mega')">Mega Caps</button>
      <button class="preset-btn" onclick="loadPreset('ev')">EV Stocks</button>
      <button class="preset-btn" onclick="loadPreset('ai')">AI Plays</button>
      <button class="preset-btn" onclick="loadPreset('semi')">Semiconductors</button>
    </div>

    <!-- Saved Watchlists -->
    <div class="watchlist-section" id="watchlistSection" style="display:none">
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
        <span class="section-title" style="margin:0">Saved Watchlists</span>
        <button class="btn btn-sm btn-outline" onclick="saveCurrentAsWatchlist()">+ Save Current</button>
      </div>
      <div class="watchlist-row" id="watchlistRow"></div>
    </div>

    <!-- Progress -->
    <div class="progress-container" id="progressContainer">
      <div class="progress-bar-track"><div class="progress-bar-fill" id="progressBar"></div></div>
      <div class="progress-text">
        <span id="progressLabel">Analyzing...</span>
        <span id="progressCount">0/0</span>
      </div>
    </div>
  </section>

  <!-- Results -->
  <div class="results-grid" id="resultsGrid" role="region" aria-label="Analysis results"></div>

  <!-- TradingView Export Panel -->
  <section class="tv-export-section" id="tvExportSection" aria-label="TradingView export">
    <h2>TradingView Export</h2>
    <div class="tv-btn-row" style="margin-bottom:16px">
      <button class="btn btn-sm btn-outline" onclick="copyAllLevels()">Copy All Levels</button>
      <button class="btn btn-sm btn-outline" onclick="copyTVLevels()">Copy TV Prices</button>
      <button class="btn btn-sm btn-outline" onclick="downloadCSV()">Download CSV</button>
      <button class="btn btn-sm btn-outline" onclick="copyPineScript()">Copy Pine Script</button>
    </div>
    <div class="tv-export-grid">
      <div>
        <div class="section-title">CSV Preview</div>
        <div class="tv-code-block" id="csvPreview"></div>
      </div>
      <div>
        <div class="section-title">Pine Script</div>
        <div class="tv-code-block" id="pinePreview"></div>
      </div>
    </div>
  </section>
</main>

<!-- Toast -->
<div class="toast" id="toast"></div>

<script>
// ─── Configuration ──────────────────────────────────────────────────────────
// Set your Cloudflare Worker URL here:
const WORKER_URL = '';

// Presets
const PRESETS = {
  tech: ['AAPL', 'MSFT', 'GOOGL', 'META', 'AMZN', 'NVDA', 'AMD', 'TSLA'],
  mega: ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'BRK.B', 'JPM'],
  ev: ['TSLA', 'RIVN', 'LCID', 'NIO', 'XPEV', 'F', 'GM'],
  ai: ['NVDA', 'AMD', 'MSFT', 'GOOGL', 'META', 'PLTR', 'SNOW'],
  semi: ['NVDA', 'AMD', 'INTC', 'TSM', 'QCOM', 'AVGO', 'MU', 'ASML'],
};

// State
let allResults = [];
let watchlists = JSON.parse(localStorage.getItem('oih_watchlists') || '{}');

// ─── Theme ──────────────────────────────────────────────────────────────────

function toggleTheme() {
  const html = document.documentElement;
  const isDark = html.getAttribute('data-theme') === 'dark';
  html.setAttribute('data-theme', isDark ? 'light' : 'dark');
  document.getElementById('themeIcon').innerHTML = isDark ? '&#9790;' : '&#9788;';
  localStorage.setItem('oih_theme', isDark ? 'light' : 'dark');
}

(function initTheme() {
  const saved = localStorage.getItem('oih_theme');
  if (saved === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark');
    document.getElementById('themeIcon').innerHTML = '&#9788;';
  }
})();

// ─── Toast ──────────────────────────────────────────────────────────────────

function showToast(msg, duration = 2500) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), duration);
}

// ─── Presets & Watchlists ───────────────────────────────────────────────────

function loadPreset(key) {
  document.getElementById('bulkInput').value = PRESETS[key].join(', ');
  document.getElementById('tickerInput').value = '';
}

function renderWatchlists() {
  const section = document.getElementById('watchlistSection');
  const row = document.getElementById('watchlistRow');
  const names = Object.keys(watchlists);
  if (names.length === 0) { section.style.display = 'none'; return; }
  section.style.display = 'block';
  row.innerHTML = names.map(name =>
    \`<span class="watchlist-chip" onclick="loadWatchlist('\${name}')">\${name} <span class="remove" onclick="event.stopPropagation();deleteWatchlist('\${name}')">&times;</span></span>\`
  ).join('');
}

function saveCurrentAsWatchlist() {
  const symbols = getSymbolsList();
  if (symbols.length === 0) { showToast('No symbols to save'); return; }
  const name = prompt('Watchlist name:');
  if (!name) return;
  watchlists[name] = symbols;
  localStorage.setItem('oih_watchlists', JSON.stringify(watchlists));
  renderWatchlists();
  showToast(\`Saved "\${name}"\`);
}

function loadWatchlist(name) {
  document.getElementById('bulkInput').value = watchlists[name].join(', ');
  document.getElementById('tickerInput').value = '';
}

function deleteWatchlist(name) {
  delete watchlists[name];
  localStorage.setItem('oih_watchlists', JSON.stringify(watchlists));
  renderWatchlists();
}

renderWatchlists();

// ─── Analysis ───────────────────────────────────────────────────────────────

function getSymbolsList() {
  const single = document.getElementById('tickerInput').value.trim().toUpperCase();
  const bulk = document.getElementById('bulkInput').value.trim().toUpperCase();
  const symbols = [];
  if (single) symbols.push(single);
  if (bulk) {
    bulk.split(/[,\\s]+/).forEach(s => {
      s = s.trim();
      if (s && !symbols.includes(s)) symbols.push(s);
    });
  }
  return symbols;
}

async function analyzeStocks() {
  const symbols = getSymbolsList();
  if (symbols.length === 0) {
    showToast('Enter at least one ticker symbol');
    return;
  }

  const btn = document.getElementById('analyzeBtn');
  const grid = document.getElementById('resultsGrid');
  const progress = document.getElementById('progressContainer');

  btn.disabled = true;
  btn.textContent = 'Analyzing...';
  progress.classList.add('active');
  grid.innerHTML = '';
  allResults = [];

  // Show skeleton cards
  grid.innerHTML = symbols.map(() =>
    \`<div class="skeleton-card"><div class="skeleton-line h24 w60"></div><div class="skeleton-line w80"></div><div class="skeleton-line w40"></div><div class="skeleton-line w80"></div><div class="skeleton-line w60"></div><div class="skeleton-line w80"></div></div>\`
  ).join('');

  let completed = 0;
  const updateProgress = () => {
    completed++;
    const pct = (completed / symbols.length * 100).toFixed(0);
    document.getElementById('progressBar').style.width = pct + '%';
    document.getElementById('progressCount').textContent = \`\${completed}/\${symbols.length}\`;
    document.getElementById('progressLabel').textContent = completed === symbols.length ? 'Complete' : \`Analyzing \${symbols[completed] || ''}...\`;
  };

  // Fetch all in parallel (batches of 5)
  const results = [];
  for (let i = 0; i < symbols.length; i += 5) {
    const batch = symbols.slice(i, i + 5);
    const batchResults = await Promise.allSettled(
      batch.map(async sym => {
        try {
          const resp = await fetch(\`\${WORKER_URL}/options/\${sym}\`);
          const data = await resp.json();
          updateProgress();
          return data;
        } catch (err) {
          updateProgress();
          return { symbol: sym, error: err.message };
        }
      })
    );
    results.push(...batchResults.map(r => r.status === 'fulfilled' ? r.value : { error: r.reason?.message }));
  }

  allResults = results;
  grid.innerHTML = '';

  results.forEach(data => {
    if (data.error) {
      grid.innerHTML += renderErrorCard(data);
    } else {
      grid.innerHTML += renderStockCard(data);
    }
  });

  // Show TV export if we have results
  const validResults = results.filter(r => !r.error);
  if (validResults.length > 0) {
    document.getElementById('tvExportSection').classList.add('active');
    updateExportPreviews(validResults);
  }

  btn.disabled = false;
  btn.textContent = 'Calculate Levels';
  progress.classList.remove('active');
  document.getElementById('dataFreshness').textContent = \`Updated: \${new Date().toLocaleTimeString()}\`;
}

// ─── Render: Error Card ─────────────────────────────────────────────────────

function renderErrorCard(data) {
  return \`<div class="error-card"><h3>\${data.symbol || 'Error'}</h3><p>\${data.error}</p></div>\`;
}

// ─── Render: Stock Card ─────────────────────────────────────────────────────

function renderStockCard(d) {
  const a = d.analysis;
  const price = d.currentPrice;
  const isUp = d.priceChange >= 0;
  const changeClass = isUp ? 'up' : 'down';
  const changeSign = isUp ? '+' : '';

  // Build levels for the price ladder
  const levels = [];
  if (a.walls.putWallDelta) levels.push({ price: a.walls.putWallDelta, label: 'Put Wall', color: 'var(--put-wall)', pos: 'below' });
  if (a.walls.putWallOI) levels.push({ price: a.walls.putWallOI, label: 'Put OI', color: 'var(--oi-wall)', pos: 'below' });
  if (a.gex.support) levels.push({ price: a.gex.support, label: 'GEX Sup', color: 'var(--gex)', pos: 'below' });
  if (a.maxPain) levels.push({ price: a.maxPain, label: 'Max Pain', color: 'var(--max-pain)', pos: 'above' });
  if (a.volumeProfile.poc) levels.push({ price: a.volumeProfile.poc, label: 'POC', color: 'var(--volume-poc)', pos: 'above' });
  if (a.gex.resistance) levels.push({ price: a.gex.resistance, label: 'GEX Res', color: 'var(--gex)', pos: 'above' });
  if (a.walls.callWallDelta) levels.push({ price: a.walls.callWallDelta, label: 'Call Wall', color: 'var(--call-wall)', pos: 'above' });
  if (a.walls.callWallOI) levels.push({ price: a.walls.callWallOI, label: 'Call OI', color: 'var(--oi-wall)', pos: 'above' });

  // Price range for ladder
  const allPrices = [price, ...levels.map(l => l.price)].filter(Boolean);
  const minP = Math.min(...allPrices) * 0.995;
  const maxP = Math.max(...allPrices) * 1.005;
  const range = maxP - minP;

  const pctPos = (p) => ((p - minP) / range * 80 + 10).toFixed(1); // 10-90% range

  const ladderMarkers = levels.map(l =>
    \`<div class="ladder-marker \${l.pos}" style="left:\${pctPos(l.price)}%">
      <div class="ladder-dot" style="background:\${l.color}"></div>
      <div class="ladder-label" style="color:\${l.color}">\${l.label}</div>
      <div class="ladder-price-label">$\${l.price.toFixed(2)}</div>
    </div>\`
  ).join('');

  const pctFromPrice = (val) => {
    if (!val) return '';
    const pct = ((val - price) / price * 100).toFixed(1);
    return pct >= 0 ? \`+\${pct}%\` : \`\${pct}%\`;
  };

  // Top OI bars
  const topOI = a.biggestStrikes.topOIStrikes || [];
  const maxOI = topOI.length > 0 ? topOI[0].totalOI : 1;
  const oiBars = topOI.slice(0, 5).map(s =>
    \`<div class="strike-bar-container">
      <div class="strike-bar-header">
        <span class="strike-bar-label">$\${s.strike.toFixed(2)}</span>
        <span class="strike-bar-value">\${formatNum(s.totalOI)} OI</span>
      </div>
      <div class="strike-bar-track">
        <div class="strike-bar-fill" style="width:\${(s.totalOI/maxOI*100).toFixed(0)}%;background:var(--oi-wall)"></div>
      </div>
    </div>\`
  ).join('');

  // Top Volume bars
  const topVol = a.volumeProfile.topVolumeStrikes || [];
  const maxVol = topVol.length > 0 ? topVol[0].volume : 1;
  const volBars = topVol.slice(0, 3).map(s =>
    \`<div class="strike-bar-container">
      <div class="strike-bar-header">
        <span class="strike-bar-label">$\${s.strike.toFixed(2)}</span>
        <span class="strike-bar-value">\${formatNum(s.volume)} vol</span>
      </div>
      <div class="strike-bar-track">
        <div class="strike-bar-fill" style="width:\${(s.volume/maxVol*100).toFixed(0)}%;background:var(--volume-poc)"></div>
      </div>
    </div>\`
  ).join('');

  return \`
  <div class="stock-card" data-symbol="\${d.symbol}">
    <div class="card-header">
      <div>
        <div class="card-symbol">\${d.symbol}</div>
        <div style="font-size:11px;color:var(--text-muted)">Exp: \${d.expiration} | \${d.dataQuality.strikesAnalyzed} strikes</div>
      </div>
      <div class="card-price-group">
        <div class="card-price">$\${price.toFixed(2)}</div>
        <div class="card-change \${changeClass}">\${changeSign}\${d.priceChange.toFixed(2)} (\${changeSign}\${d.priceChangePercent.toFixed(2)}%)</div>
      </div>
    </div>

    <div class="card-body">
      <!-- Price Ladder -->
      <div class="price-ladder" aria-label="Price ladder visualization">
        <div class="ladder-bar"></div>
        <div class="ladder-current" style="left:\${pctPos(price)}%" data-price="$\${price.toFixed(2)}"></div>
        \${ladderMarkers}
      </div>

      <!-- Key Levels Grid -->
      <div class="levels-grid">
        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--max-pain)"></div>
          <div class="level-info">
            <div class="level-label">Max Pain</div>
            <div class="level-value">\${a.maxPain ? '$' + a.maxPain.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.maxPain)}</span></div>
          </div>
          <span class="tooltip-text">Strike where option sellers profit most. Price tends to gravitate here near expiration.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--primary)"></div>
          <div class="level-info">
            <div class="level-label">Expected Range</div>
            <div class="level-value">$\${a.expectedLow.toFixed(2)} - $\${a.expectedHigh.toFixed(2)} <span class="level-pct">\${a.rangePercent}%</span></div>
          </div>
          <span class="tooltip-text">Predicted trading range based on GEX, max pain, and delta walls.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--call-wall)"></div>
          <div class="level-info">
            <div class="level-label">Call Wall (Delta)</div>
            <div class="level-value">\${a.walls.callWallDelta ? '$' + a.walls.callWallDelta.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.walls.callWallDelta)}</span></div>
          </div>
          <span class="tooltip-text">Strongest resistance from delta-weighted call OI. Market makers sell here.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--put-wall)"></div>
          <div class="level-info">
            <div class="level-label">Put Wall (Delta)</div>
            <div class="level-value">\${a.walls.putWallDelta ? '$' + a.walls.putWallDelta.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.walls.putWallDelta)}</span></div>
          </div>
          <span class="tooltip-text">Strongest support from delta-weighted put OI. Market makers buy here.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--oi-wall)"></div>
          <div class="level-info">
            <div class="level-label">Call Wall (OI)</div>
            <div class="level-value">\${a.walls.callWallOI ? '$' + a.walls.callWallOI.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.walls.callWallOI)}</span></div>
          </div>
          <span class="tooltip-text">Strike with highest call open interest above price. Major resistance magnet.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--oi-wall)"></div>
          <div class="level-info">
            <div class="level-label">Put Wall (OI)</div>
            <div class="level-value">\${a.walls.putWallOI ? '$' + a.walls.putWallOI.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.walls.putWallOI)}</span></div>
          </div>
          <span class="tooltip-text">Strike with highest put open interest below price. Major support magnet.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--gex)"></div>
          <div class="level-info">
            <div class="level-label">GEX Resistance</div>
            <div class="level-value">\${a.gex.resistance ? '$' + a.gex.resistance.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.gex.resistance)}</span></div>
          </div>
          <span class="tooltip-text">Highest positive gamma exposure above price. Dealers hedge aggressively here.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--gex)"></div>
          <div class="level-info">
            <div class="level-label">GEX Support</div>
            <div class="level-value">\${a.gex.support ? '$' + a.gex.support.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.gex.support)}</span></div>
          </div>
          <span class="tooltip-text">Highest positive gamma exposure below price. Dealers provide support here.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--gex);opacity:0.5"></div>
          <div class="level-info">
            <div class="level-label">Zero GEX (Flip)</div>
            <div class="level-value">\${a.gex.zero ? '$' + a.gex.zero.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.gex.zero)}</span></div>
          </div>
          <span class="tooltip-text">Gamma flip point. Above = dealer dampening. Below = dealer amplifying moves.</span>
        </div>

        <div class="level-item tooltip-trigger">
          <div class="level-dot" style="background:var(--volume-poc)"></div>
          <div class="level-info">
            <div class="level-label">Volume POC</div>
            <div class="level-value">\${a.volumeProfile.poc ? '$' + a.volumeProfile.poc.toFixed(2) : 'N/A'} <span class="level-pct">\${pctFromPrice(a.volumeProfile.poc)}</span></div>
          </div>
          <span class="tooltip-text">Point of Control - strike with highest options volume. Key magnet level.</span>
        </div>

        <div class="level-item">
          <div class="level-dot" style="background:\${a.gex.netGEX === 'POSITIVE' ? 'var(--success)' : 'var(--danger)'}"></div>
          <div class="level-info">
            <div class="level-label">Net GEX</div>
            <div class="level-value" style="color:\${a.gex.netGEX === 'POSITIVE' ? 'var(--success)' : 'var(--danger)'}">\${a.gex.netGEX}</div>
          </div>
        </div>

        <div class="level-item">
          <div class="level-dot" style="background:var(--text-muted)"></div>
          <div class="level-info">
            <div class="level-label">P/C Ratio</div>
            <div class="level-value">\${d.dataQuality.putCallRatio || 'N/A'}</div>
          </div>
        </div>
      </div>

      <!-- Top OI Strikes -->
      \${topOI.length > 0 ? \`
      <div class="top-strikes">
        <div class="section-title">Biggest Open Interest Strikes</div>
        \${oiBars}
      </div>\` : ''}

      <!-- Top Volume Strikes -->
      \${topVol.length > 0 ? \`
      <div class="top-strikes">
        <div class="section-title">Top Volume Strikes</div>
        \${volBars}
      </div>\` : ''}
    </div>

    <!-- Export Buttons -->
    <div class="card-export">
      <button class="export-btn" onclick="copySingleLevels('\${d.symbol}')">Copy Levels</button>
      <button class="export-btn" onclick="copySingleCSV('\${d.symbol}')">Copy CSV</button>
      <button class="export-btn" onclick="copySinglePine('\${d.symbol}')">Copy Pine</button>
    </div>
  </div>\`;
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function formatNum(n) {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return n.toString();
}

// ─── Export Functions ───────────────────────────────────────────────────────

function getResultBySymbol(sym) {
  return allResults.find(r => r.symbol === sym);
}

function buildLevelsText(d) {
  const a = d.analysis;
  const lines = [
    \`=== \${d.symbol} Options Levels ===\`,
    \`Current Price: $\${d.currentPrice.toFixed(2)}\`,
    \`Expiration: \${d.expiration}\`,
    '',
    \`Max Pain: $\${a.maxPain?.toFixed(2) || 'N/A'}\`,
    \`Expected Range: $\${a.expectedLow.toFixed(2)} - $\${a.expectedHigh.toFixed(2)} (\${a.rangePercent}%)\`,
    '',
    \`Call Wall (Delta): $\${a.walls.callWallDelta?.toFixed(2) || 'N/A'}\`,
    \`Put Wall (Delta): $\${a.walls.putWallDelta?.toFixed(2) || 'N/A'}\`,
    \`Call Wall (OI): $\${a.walls.callWallOI?.toFixed(2) || 'N/A'}\`,
    \`Put Wall (OI): $\${a.walls.putWallOI?.toFixed(2) || 'N/A'}\`,
    '',
    \`GEX Resistance: $\${a.gex.resistance?.toFixed(2) || 'N/A'}\`,
    \`GEX Support: $\${a.gex.support?.toFixed(2) || 'N/A'}\`,
    \`Zero GEX: $\${a.gex.zero?.toFixed(2) || 'N/A'}\`,
    \`Net GEX: \${a.gex.netGEX}\`,
    '',
    \`Volume POC: $\${a.volumeProfile.poc?.toFixed(2) || 'N/A'}\`,
    \`Biggest OI: $\${a.biggestStrikes.totalOI?.strike?.toFixed(2) || 'N/A'} (\${formatNum(a.biggestStrikes.totalOI?.oi || 0)} contracts)\`,
  ];
  return lines.join('\\n');
}

function buildCSVRows(d) {
  const a = d.analysis;
  const rows = [];
  const add = (type, price, label) => { if (price) rows.push(\`\${d.symbol},\${type},\${price.toFixed(2)},\${label}\`); };
  add('Max_Pain', a.maxPain, 'Max Pain');
  add('Call_Wall_Delta', a.walls.callWallDelta, 'Call Wall (Delta)');
  add('Put_Wall_Delta', a.walls.putWallDelta, 'Put Wall (Delta)');
  add('Call_Wall_OI', a.walls.callWallOI, 'Call Wall (OI)');
  add('Put_Wall_OI', a.walls.putWallOI, 'Put Wall (OI)');
  add('GEX_Resistance', a.gex.resistance, 'GEX Resistance');
  add('GEX_Support', a.gex.support, 'GEX Support');
  add('Zero_GEX', a.gex.zero, 'Zero GEX');
  add('Volume_POC', a.volumeProfile.poc, 'Volume POC');
  if (a.biggestStrikes.totalOI) add('Biggest_OI', a.biggestStrikes.totalOI.strike, 'Biggest OI');
  return rows;
}

function buildPineScript(results) {
  const date = new Date().toLocaleDateString();
  let pine = \`//@version=5
indicator("Options Levels - \${date}", overlay=true)

ticker = syminfo.ticker

\`;

  for (const d of results) {
    const a = d.analysis;
    const s = d.symbol.toLowerCase().replace('.', '_');
    pine += \`// \${d.symbol} Levels\\n\`;
    pine += \`\${s}_max_pain = \${a.maxPain?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_call_wall_delta = \${a.walls.callWallDelta?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_put_wall_delta = \${a.walls.putWallDelta?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_call_wall_oi = \${a.walls.callWallOI?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_put_wall_oi = \${a.walls.putWallOI?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_gex_resistance = \${a.gex.resistance?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_gex_support = \${a.gex.support?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_zero_gex = \${a.gex.zero?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_volume_poc = \${a.volumeProfile.poc?.toFixed(2) || 'na'}\\n\`;
    pine += \`\${s}_biggest_oi = \${a.biggestStrikes.totalOI?.strike?.toFixed(2) || 'na'}\\n\\n\`;
  }

  // Auto-select
  const first = results[0];
  const fs = first.symbol.toLowerCase().replace('.', '_');
  pine += \`// Auto-select based on ticker\\n\`;

  const levelNames = ['max_pain', 'call_wall_delta', 'put_wall_delta', 'call_wall_oi', 'put_wall_oi', 'gex_resistance', 'gex_support', 'zero_gex', 'volume_poc', 'biggest_oi'];

  for (const ln of levelNames) {
    pine += \`\${ln} = \`;
    const parts = results.map(d => {
      const s = d.symbol.toLowerCase().replace('.', '_');
      return \`ticker == "\${d.symbol}" ? \${s}_\${ln}\`;
    });
    pine += parts.join(' : ') + ' : na\\n';
  }

  pine += \`
// Plot levels
plot(max_pain, "Max Pain", color.yellow, 3, plot.style_cross)
plot(call_wall_delta, "Call Wall (Delta)", color.red, 2)
plot(put_wall_delta, "Put Wall (Delta)", color.green, 2)
plot(call_wall_oi, "Call Wall (OI)", color.new(color.red, 50), 2, plot.style_circles)
plot(put_wall_oi, "Put Wall (OI)", color.new(color.green, 50), 2, plot.style_circles)
plot(gex_resistance, "GEX Resistance", color.purple, 1)
plot(gex_support, "GEX Support", color.purple, 1)
plot(zero_gex, "Zero GEX", color.new(color.purple, 50), 1, plot.style_cross)
plot(volume_poc, "Volume POC", color.blue, 2, plot.style_stepline)
plot(biggest_oi, "Biggest OI", color.orange, 2, plot.style_circles)
\`;

  return pine;
}

function updateExportPreviews(results) {
  // CSV
  let csv = 'Symbol,Level_Type,Price,Label\\n';
  for (const d of results) {
    csv += buildCSVRows(d).join('\\n') + '\\n';
  }
  document.getElementById('csvPreview').textContent = csv;

  // Pine Script
  const pine = buildPineScript(results);
  document.getElementById('pinePreview').textContent = pine;
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => showToast('Copied to clipboard'));
}

function copySingleLevels(sym) {
  const d = getResultBySymbol(sym);
  if (d) copyToClipboard(buildLevelsText(d));
}

function copySingleCSV(sym) {
  const d = getResultBySymbol(sym);
  if (d) copyToClipboard('Symbol,Level_Type,Price,Label\\n' + buildCSVRows(d).join('\\n'));
}

function copySinglePine(sym) {
  const d = getResultBySymbol(sym);
  if (d) copyToClipboard(buildPineScript([d]));
}

function copyAllLevels() {
  const valid = allResults.filter(r => !r.error);
  const text = valid.map(d => buildLevelsText(d)).join('\\n\\n');
  copyToClipboard(text);
}

function copyTVLevels() {
  const valid = allResults.filter(r => !r.error);
  const lines = [];
  for (const d of valid) {
    const a = d.analysis;
    const vals = [a.maxPain, a.walls.callWallDelta, a.walls.putWallDelta, a.walls.callWallOI, a.walls.putWallOI, a.gex.resistance, a.gex.support, a.gex.zero, a.volumeProfile.poc, a.biggestStrikes.totalOI?.strike];
    lines.push(\`\${d.symbol}: \${vals.filter(Boolean).map(v => v.toFixed(2)).join(', ')}\`);
  }
  copyToClipboard(lines.join('\\n'));
}

function downloadCSV() {
  const valid = allResults.filter(r => !r.error);
  let csv = 'Symbol,Level_Type,Price,Label\\n';
  for (const d of valid) csv += buildCSVRows(d).join('\\n') + '\\n';
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = \`options-levels-\${new Date().toISOString().slice(0,10)}.csv\`;
  a.click();
  URL.revokeObjectURL(url);
  showToast('CSV downloaded');
}

function copyPineScript() {
  const valid = allResults.filter(r => !r.error);
  if (valid.length > 0) copyToClipboard(buildPineScript(valid));
}
</script>
</body>
</html>
`;

// ─── CORS Headers ────────────────────────────────────────────────────────────

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

const FETCH_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  'Accept': 'application/json',
  'Accept-Language': 'en-US,en;q=0.9',
};

// ─── Request Router ──────────────────────────────────────────────────────────

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const path = url.pathname;

    // Serve frontend at root
    if (path === '/' || path === '/index.html') {
      return new Response(HTML_PAGE, {
        headers: { 'Content-Type': 'text/html;charset=UTF-8' }
      });
    }

    // Health check
    if (path === '/health') {
      return jsonResponse({ status: 'ok', service: 'Options Intelligence Hub', source: 'CBOE' });
    }

    // Options analysis: /options/TSLA
    const match = path.match(/^\/options\/([A-Za-z.]+)$/);
    if (match) {
      const ticker = match[1].toUpperCase();
      try {
        const result = await analyzeOptions(ticker);
        return jsonResponse(result);
      } catch (err) {
        return jsonResponse({ error: err.message, symbol: ticker }, 500);
      }
    }

    // Batch: /batch?symbols=TSLA,AAPL,NVDA
    if (path === '/batch') {
      const symbols = (url.searchParams.get('symbols') || '').split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
      if (symbols.length === 0) return jsonResponse({ error: 'No symbols provided. Use ?symbols=TSLA,AAPL' }, 400);
      if (symbols.length > 15) return jsonResponse({ error: 'Max 15 symbols per batch' }, 400);

      const results = await Promise.allSettled(symbols.map(s => analyzeOptions(s)));
      const data = symbols.map((sym, i) =>
        results[i].status === 'fulfilled' ? results[i].value : { symbol: sym, error: results[i].reason?.message || 'Unknown error' }
      );
      return jsonResponse({ results: data });
    }

    // Debug: /debug/TSLA
    const debugMatch = path.match(/^\/debug\/([A-Za-z.]+)$/);
    if (debugMatch) {
      const ticker = debugMatch[1].toUpperCase();
      try {
        const [quote, options] = await Promise.all([
          fetchCBOEQuote(ticker),
          fetchCBOEOptions(ticker),
        ]);
        return jsonResponse({ symbol: ticker, quote, optionsCount: options.length, sampleOptions: options.slice(0, 5) });
      } catch (err) {
        return jsonResponse({ error: err.message, symbol: ticker }, 500);
      }
    }

    return jsonResponse({ error: 'Not found. Use /options/TSLA or /batch?symbols=TSLA,AAPL' }, 404);
  }
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: CORS_HEADERS });
}

// ─── Main Analysis Pipeline ──────────────────────────────────────────────────

async function analyzeOptions(ticker) {
  // Fetch quote and options in parallel from CBOE
  const [quoteData, rawOptions] = await Promise.all([
    fetchCBOEQuote(ticker),
    fetchCBOEOptions(ticker),
  ]);

  const currentPrice = quoteData.current_price;
  if (!currentPrice) throw new Error(`No price data for ${ticker}`);

  // Parse and filter options
  const options = parseCBOEOptions(rawOptions, currentPrice);

  if (options.length === 0) {
    throw new Error(`No options data available for ${ticker}. The stock may not have listed options.`);
  }

  // Find nearest expiration from the parsed options
  const expirations = [...new Set(options.map(o => o.expiration))].sort();
  const nearestExp = expirations[0] || 'N/A';

  // Filter to nearest expiration only for calculations
  const nearestOptions = options.filter(o => o.expiration === nearestExp);

  // Aggregate by strike (combine all expirations data by strike)
  // But use nearest expiration for primary analysis
  const strikeData = aggregateByStrike(nearestOptions);

  if (strikeData.length === 0) {
    throw new Error(`No near-term options data for ${ticker}`);
  }

  // Run calculations
  const maxPain = calculateMaxPain(strikeData);
  const gex = calculateGEX(strikeData, currentPrice);
  const deltaWalls = calculateDeltaWalls(strikeData, currentPrice);
  const volumeProfile = calculateVolumeProfile(strikeData);
  const biggestStrikes = calculateBiggestStrikes(strikeData);
  const expectedRange = calculateExpectedRange(strikeData, currentPrice, maxPain, gex, deltaWalls);

  const totalCallOI = strikeData.reduce((s, o) => s + o.callOI, 0);
  const totalPutOI = strikeData.reduce((s, o) => s + o.putOI, 0);
  const totalCallVolume = strikeData.reduce((s, o) => s + o.callVolume, 0);
  const totalPutVolume = strikeData.reduce((s, o) => s + o.putVolume, 0);

  // Days to expiration
  let daysToExpiration = 0;
  if (nearestExp !== 'N/A') {
    const expDate = new Date(nearestExp + 'T16:00:00');
    daysToExpiration = Math.max(0, Math.ceil((expDate - new Date()) / (1000 * 60 * 60 * 24)));
  }

  return {
    symbol: ticker,
    currentPrice,
    priceChange: quoteData.price_change || 0,
    priceChangePercent: quoteData.price_change_percent || 0,
    expiration: nearestExp,
    daysToExpiration,
    analysis: {
      maxPain,
      expectedLow: expectedRange.low,
      expectedHigh: expectedRange.high,
      rangeWidth: +(expectedRange.high - expectedRange.low).toFixed(2),
      rangePercent: +((expectedRange.high - expectedRange.low) / currentPrice * 100).toFixed(2),
      walls: deltaWalls,
      gex,
      volumeProfile,
      biggestStrikes,
    },
    dataQuality: {
      totalCallOI,
      totalPutOI,
      totalCallVolume,
      totalPutVolume,
      strikesAnalyzed: strikeData.length,
      putCallRatio: totalPutOI > 0 ? +(totalCallOI / totalPutOI).toFixed(2) : 0,
    },
    timestamp: new Date().toISOString(),
  };
}

// ─── CBOE Data Fetching ─────────────────────────────────────────────────────

async function fetchCBOEQuote(ticker) {
  const url = `https://cdn.cboe.com/api/global/delayed_quotes/quotes/${ticker}.json`;
  const resp = await fetch(url, { headers: FETCH_HEADERS });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    throw new Error(`CBOE quote API returned ${resp.status} for ${ticker}. ${text.slice(0, 100)}`);
  }

  const json = await resp.json();
  if (!json.data) throw new Error(`No quote data returned for ${ticker}`);
  return json.data;
}

async function fetchCBOEOptions(ticker) {
  const url = `https://cdn.cboe.com/api/global/delayed_quotes/options/${ticker}.json`;
  const resp = await fetch(url, { headers: FETCH_HEADERS });

  if (!resp.ok) {
    // Try with underscore prefix for some index options
    const url2 = `https://cdn.cboe.com/api/global/delayed_quotes/options/_${ticker}.json`;
    const resp2 = await fetch(url2, { headers: FETCH_HEADERS });
    if (!resp2.ok) {
      throw new Error(`CBOE options API returned ${resp.status} for ${ticker}. Ticker may be invalid or have no listed options.`);
    }
    const json2 = await resp2.json();
    return json2.data?.options || [];
  }

  const json = await resp.json();
  return json.data?.options || [];
}

// ─── Parse CBOE Options ─────────────────────────────────────────────────────

function parseCBOEOptions(rawOptions, currentPrice) {
  // CBOE option symbol format: TSLA260218C00322500
  // Ticker + YYMMDD + C/P + strike*1000 (8 digits)
  const parsed = [];

  for (const opt of rawOptions) {
    const sym = opt.option;
    if (!sym) continue;

    // Extract expiration and type from symbol
    const symbolMatch = sym.match(/^([A-Z.]+)(\d{6})([CP])(\d{8})$/);
    if (!symbolMatch) continue;

    const expYY = symbolMatch[2].slice(0, 2);
    const expMM = symbolMatch[2].slice(2, 4);
    const expDD = symbolMatch[2].slice(4, 6);
    const expiration = `20${expYY}-${expMM}-${expDD}`;
    const isCall = symbolMatch[3] === 'C';
    const strike = parseInt(symbolMatch[4]) / 1000;

    if (strike <= 0) continue;
    // Filter to ±30% of current price
    if (strike < currentPrice * 0.7 || strike > currentPrice * 1.3) continue;

    parsed.push({
      symbol: sym,
      strike,
      expiration,
      isCall,
      bid: opt.bid || 0,
      ask: opt.ask || 0,
      volume: opt.volume || 0,
      openInterest: opt.open_interest || 0,
      delta: opt.delta || 0,
      gamma: opt.gamma || 0,
      vega: opt.vega || 0,
      theta: opt.theta || 0,
      iv: opt.iv || 0,
      lastPrice: opt.last_trade_price || 0,
    });
  }

  return parsed;
}

function aggregateByStrike(options) {
  const strikeMap = new Map();

  for (const opt of options) {
    if (!strikeMap.has(opt.strike)) {
      strikeMap.set(opt.strike, {
        strike: opt.strike,
        callOI: 0, putOI: 0,
        callVolume: 0, putVolume: 0,
        callDelta: 0, putDelta: 0,
        callGamma: 0, putGamma: 0,
        callBid: 0, callAsk: 0,
        putBid: 0, putAsk: 0,
        callIV: 0, putIV: 0,
      });
    }

    const entry = strikeMap.get(opt.strike);
    if (opt.isCall) {
      entry.callOI = opt.openInterest;
      entry.callVolume = opt.volume;
      entry.callDelta = opt.delta;
      entry.callGamma = opt.gamma;
      entry.callBid = opt.bid;
      entry.callAsk = opt.ask;
      entry.callIV = opt.iv;
    } else {
      entry.putOI = opt.openInterest;
      entry.putVolume = opt.volume;
      entry.putDelta = opt.delta;
      entry.putGamma = opt.gamma;
      entry.putBid = opt.bid;
      entry.putAsk = opt.ask;
      entry.putIV = opt.iv;
    }
  }

  return Array.from(strikeMap.values()).sort((a, b) => a.strike - b.strike);
}

// ─── Calculation: Max Pain ───────────────────────────────────────────────────

function calculateMaxPain(options) {
  let minPain = Infinity;
  let maxPainStrike = 0;

  for (const opt of options) {
    let totalPain = 0;
    for (const other of options) {
      if (opt.strike > other.strike) {
        totalPain += (opt.strike - other.strike) * other.callOI;
      }
      if (opt.strike < other.strike) {
        totalPain += (other.strike - opt.strike) * other.putOI;
      }
    }
    if (totalPain < minPain) {
      minPain = totalPain;
      maxPainStrike = opt.strike;
    }
  }
  return maxPainStrike;
}

// ─── Calculation: GEX (Gamma Exposure) ──────────────────────────────────────

function calculateGEX(options, spotPrice) {
  const gexByStrike = [];

  for (const opt of options) {
    // Use real gamma from CBOE
    const callGEX = opt.callGamma * opt.callOI * 100 * spotPrice;
    const putGEX = -opt.putGamma * opt.putOI * 100 * spotPrice;
    const netGEX = callGEX + putGEX;
    gexByStrike.push({ strike: opt.strike, callGEX, putGEX, netGEX });
  }

  const abovePrice = gexByStrike.filter(g => g.strike > spotPrice && g.netGEX > 0);
  const belowPrice = gexByStrike.filter(g => g.strike < spotPrice && g.netGEX > 0);

  const resistance = abovePrice.length > 0
    ? abovePrice.reduce((max, g) => g.netGEX > max.netGEX ? g : max).strike : null;
  const support = belowPrice.length > 0
    ? belowPrice.reduce((max, g) => g.netGEX > max.netGEX ? g : max).strike : null;

  const nearATM = gexByStrike.filter(g => Math.abs(g.strike - spotPrice) / spotPrice < 0.15);
  const zeroGEX = nearATM.length > 0
    ? nearATM.reduce((min, g) => Math.abs(g.netGEX) < Math.abs(min.netGEX) ? g : min).strike : null;

  const totalNetGEX = gexByStrike.reduce((s, g) => s + g.netGEX, 0);

  return {
    resistance,
    support,
    zero: zeroGEX,
    netGEX: totalNetGEX > 0 ? 'POSITIVE' : 'NEGATIVE',
    totalNetGEX: +totalNetGEX.toFixed(0),
    levels: gexByStrike.map(g => ({ strike: g.strike, netGEX: +g.netGEX.toFixed(0) })),
  };
}

// ─── Calculation: Delta Walls ───────────────────────────────────────────────

function calculateDeltaWalls(options, spotPrice) {
  let maxCallDeltaOI = 0, callWallDelta = null;
  let maxPutDeltaOI = 0, putWallDelta = null;

  for (const opt of options) {
    const callStrength = Math.abs(opt.callDelta) * opt.callOI;
    const putStrength = Math.abs(opt.putDelta) * opt.putOI;

    if (opt.strike >= spotPrice && callStrength > maxCallDeltaOI) {
      maxCallDeltaOI = callStrength;
      callWallDelta = opt.strike;
    }
    if (opt.strike <= spotPrice && putStrength > maxPutDeltaOI) {
      maxPutDeltaOI = putStrength;
      putWallDelta = opt.strike;
    }
  }

  let maxCallOI = 0, callWallOI = null;
  let maxPutOI = 0, putWallOI = null;

  for (const opt of options) {
    if (opt.strike >= spotPrice && opt.callOI > maxCallOI) {
      maxCallOI = opt.callOI;
      callWallOI = opt.strike;
    }
    if (opt.strike <= spotPrice && opt.putOI > maxPutOI) {
      maxPutOI = opt.putOI;
      putWallOI = opt.strike;
    }
  }

  return { callWallDelta, putWallDelta, callWallOI, putWallOI };
}

// ─── Calculation: Volume Profile ────────────────────────────────────────────

function calculateVolumeProfile(options) {
  const volumeData = options.map(o => ({
    strike: o.strike,
    volume: o.callVolume + o.putVolume,
    callVolume: o.callVolume,
    putVolume: o.putVolume,
  })).filter(v => v.volume > 0);

  if (volumeData.length === 0) {
    return { poc: null, highVolumeStrikes: [], topVolumeStrikes: [] };
  }

  volumeData.sort((a, b) => b.volume - a.volume);
  const poc = volumeData[0].strike;
  const avgVolume = volumeData.reduce((s, v) => s + v.volume, 0) / volumeData.length;
  const highVolumeStrikes = volumeData.filter(v => v.volume > avgVolume * 1.5).map(v => v.strike);
  const topVolumeStrikes = volumeData.slice(0, 5).map(v => ({
    strike: v.strike, volume: v.volume, callVolume: v.callVolume, putVolume: v.putVolume,
  }));

  return { poc, highVolumeStrikes, topVolumeStrikes };
}

// ─── Calculation: Biggest Strike Levels ─────────────────────────────────────

function calculateBiggestStrikes(options) {
  const oiData = options.map(o => ({
    strike: o.strike, totalOI: o.callOI + o.putOI, callOI: o.callOI, putOI: o.putOI,
  })).filter(o => o.totalOI > 0);

  oiData.sort((a, b) => b.totalOI - a.totalOI);
  const topOIStrikes = oiData.slice(0, 5).map(o => ({
    strike: o.strike, totalOI: o.totalOI, callOI: o.callOI, putOI: o.putOI,
  }));

  let maxCallOI = { strike: 0, oi: 0 };
  let maxPutOI = { strike: 0, oi: 0 };
  for (const o of options) {
    if (o.callOI > maxCallOI.oi) maxCallOI = { strike: o.strike, oi: o.callOI };
    if (o.putOI > maxPutOI.oi) maxPutOI = { strike: o.strike, oi: o.putOI };
  }

  return {
    totalOI: oiData.length > 0 ? { strike: oiData[0].strike, oi: oiData[0].totalOI } : null,
    callOI: maxCallOI,
    putOI: maxPutOI,
    topOIStrikes,
  };
}

// ─── Calculation: Expected Trading Range ────────────────────────────────────

function calculateExpectedRange(options, spotPrice, maxPain, gex, deltaWalls) {
  const levels = [
    deltaWalls.callWallDelta, deltaWalls.putWallDelta,
    deltaWalls.callWallOI, deltaWalls.putWallOI,
    gex.resistance, gex.support, maxPain,
  ].filter(v => v !== null && v !== undefined);

  const aboveLevels = levels.filter(l => l > spotPrice);
  const belowLevels = levels.filter(l => l < spotPrice);

  const high = aboveLevels.length > 0
    ? aboveLevels.sort((a, b) => a - b)[0] : spotPrice * 1.03;
  const low = belowLevels.length > 0
    ? belowLevels.sort((a, b) => b - a)[0] : spotPrice * 0.97;

  return {
    low: +Math.min(low, spotPrice).toFixed(2),
    high: +Math.max(high, spotPrice).toFixed(2),
  };
}
