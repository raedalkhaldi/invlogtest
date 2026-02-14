/**
 * Options Intelligence Hub - Cloudflare Worker
 * Uses CBOE (Chicago Board Options Exchange) delayed quotes API.
 * No API key required. Returns real Greeks (delta, gamma, vega, theta).
 * Calculates: GEX, Max Pain, Delta Walls, Volume Profile, Biggest OI Strikes, Expected Range.
 */

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

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const path = url.pathname;

    if (path === '/' || path === '/health') {
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
