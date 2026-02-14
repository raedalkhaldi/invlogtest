/**
 * Options Intelligence Hub - Cloudflare Worker
 * Fetches options chain data from Nasdaq and calculates:
 * - GEX (Gamma Exposure) Levels
 * - Max Pain
 * - Delta Walls
 * - Options Volume Profile
 * - Biggest Strike Levels (Option Walls)
 * - Expected Trading Range
 */

const NASDAQ_BASE = 'https://api.nasdaq.com/api';
const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  'Origin': 'https://www.nasdaq.com',
  'Referer': 'https://www.nasdaq.com/',
};

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const path = url.pathname;

    // Health check
    if (path === '/' || path === '/health') {
      return jsonResponse({ status: 'ok', service: 'Options Intelligence Hub' });
    }

    // Options analysis endpoint: /options/TSLA
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

    // Batch endpoint: /batch?symbols=TSLA,AAPL,NVDA
    if (path === '/batch') {
      const symbols = (url.searchParams.get('symbols') || '').split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
      if (symbols.length === 0) {
        return jsonResponse({ error: 'No symbols provided. Use ?symbols=TSLA,AAPL' }, 400);
      }
      if (symbols.length > 15) {
        return jsonResponse({ error: 'Max 15 symbols per batch request' }, 400);
      }
      const results = await Promise.allSettled(symbols.map(s => analyzeOptions(s)));
      const data = symbols.map((sym, i) => {
        if (results[i].status === 'fulfilled') return results[i].value;
        return { symbol: sym, error: results[i].reason?.message || 'Unknown error' };
      });
      return jsonResponse({ results: data });
    }

    return jsonResponse({ error: 'Not found. Use /options/TSLA or /batch?symbols=TSLA,AAPL' }, 404);
  }
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: CORS_HEADERS });
}

// ─── Main Analysis Pipeline ──────────────────────────────────────────────────

async function analyzeOptions(ticker) {
  // Fetch quote and options chain in parallel
  const [quoteData, chainData] = await Promise.all([
    fetchQuote(ticker),
    fetchOptionsChain(ticker),
  ]);

  const currentPrice = quoteData.price;
  const priceChange = quoteData.change;
  const priceChangePercent = quoteData.changePercent;

  // Parse options chain into structured data
  const options = parseOptionsChain(chainData, currentPrice);

  if (options.length === 0) {
    throw new Error(`No options data available for ${ticker}`);
  }

  // Run all calculations
  const maxPain = calculateMaxPain(options);
  const gex = calculateGEX(options, currentPrice);
  const deltaWalls = calculateDeltaWalls(options, currentPrice);
  const volumeProfile = calculateVolumeProfile(options);
  const biggestStrikes = calculateBiggestStrikes(options);
  const expectedRange = calculateExpectedRange(options, currentPrice, maxPain, gex, deltaWalls);

  // Data quality metrics
  const totalCallOI = options.reduce((s, o) => s + o.callOI, 0);
  const totalPutOI = options.reduce((s, o) => s + o.putOI, 0);
  const totalCallVolume = options.reduce((s, o) => s + o.callVolume, 0);
  const totalPutVolume = options.reduce((s, o) => s + o.putVolume, 0);

  return {
    symbol: ticker,
    currentPrice,
    priceChange,
    priceChangePercent,
    expiration: chainData.expiration || 'N/A',
    daysToExpiration: chainData.daysToExpiration || 0,
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
      strikesAnalyzed: options.length,
      putCallRatio: totalPutOI > 0 ? +(totalCallOI / totalPutOI).toFixed(2) : 0,
    },
    timestamp: new Date().toISOString(),
  };
}

// ─── Data Fetching ───────────────────────────────────────────────────────────

async function fetchQuote(ticker) {
  const url = `${NASDAQ_BASE}/quote/${ticker}/info?assetclass=stocks`;
  const resp = await fetch(url, { headers: HEADERS });
  if (!resp.ok) throw new Error(`Failed to fetch quote for ${ticker}: ${resp.status}`);
  const json = await resp.json();

  if (!json.data) throw new Error(`No quote data for ${ticker}`);

  const data = json.data;
  const priceStr = (data.primaryData?.lastSalePrice || '').replace(/[$,]/g, '');
  const price = parseFloat(priceStr);
  if (isNaN(price)) throw new Error(`Invalid price for ${ticker}`);

  const changeStr = (data.primaryData?.netChange || '0').replace(/[$,]/g, '');
  const changePctStr = (data.primaryData?.percentageChange || '0%').replace(/[%,]/g, '');

  return {
    price,
    change: parseFloat(changeStr) || 0,
    changePercent: parseFloat(changePctStr) || 0,
  };
}

async function fetchOptionsChain(ticker) {
  // First fetch to get available expirations, then get nearest expiration
  const url = `${NASDAQ_BASE}/quote/${ticker}/option-chain?assetclass=stocks&limit=1000&fromdate=all&todate=all&money=all&type=all`;
  const resp = await fetch(url, { headers: HEADERS });
  if (!resp.ok) throw new Error(`Failed to fetch options chain for ${ticker}: ${resp.status}`);
  const json = await resp.json();

  if (!json.data) throw new Error(`No options data for ${ticker}`);

  return {
    rows: json.data.table?.rows || json.data.optionChainList?.rows || [],
    expiration: json.data.table?.headers?.expiryDate || json.data.lastTrade || '',
    daysToExpiration: 0, // calculated from expiration
  };
}

function parseOptionsChain(chainData, currentPrice) {
  const rows = chainData.rows;
  if (!rows || rows.length === 0) return [];

  const options = [];

  for (const row of rows) {
    // Nasdaq API returns rows with call/put data side by side
    const strike = parseNum(row.strike);
    if (!strike || strike <= 0) continue;

    // Filter to reasonable range around current price (within 30%)
    if (strike < currentPrice * 0.7 || strike > currentPrice * 1.3) continue;

    const callOI = parseNum(row.c_Openinterest);
    const putOI = parseNum(row.p_Openinterest);
    const callVolume = parseNum(row.c_Volume);
    const putVolume = parseNum(row.p_Volume);
    const callBid = parseNum(row.c_Bid);
    const callAsk = parseNum(row.c_Ask);
    const putBid = parseNum(row.p_Bid);
    const putAsk = parseNum(row.p_Ask);

    // Parse Greeks - Nasdaq may provide these
    const callDelta = parseNum(row.c_Delta) || estimateDelta(strike, currentPrice, true);
    const putDelta = parseNum(row.p_Delta) || estimateDelta(strike, currentPrice, false);
    const callGamma = parseNum(row.c_Gamma) || estimateGamma(strike, currentPrice);
    const putGamma = parseNum(row.p_Gamma) || estimateGamma(strike, currentPrice);

    options.push({
      strike,
      callOI,
      putOI,
      callVolume,
      putVolume,
      callBid,
      callAsk,
      putBid,
      putAsk,
      callDelta,
      putDelta,
      callGamma,
      putGamma,
      callMid: (callBid + callAsk) / 2,
      putMid: (putBid + putAsk) / 2,
    });
  }

  return options.sort((a, b) => a.strike - b.strike);
}

function parseNum(val) {
  if (val === null || val === undefined || val === '' || val === '--' || val === 'N/A') return 0;
  const n = parseFloat(String(val).replace(/[,$%]/g, ''));
  return isNaN(n) ? 0 : n;
}

// ─── Greek Estimation (fallback when API doesn't provide) ────────────────────

function estimateDelta(strike, spot, isCall) {
  // Simple delta approximation using moneyness
  const moneyness = (spot - strike) / spot;
  if (isCall) {
    if (moneyness > 0.1) return 0.9;
    if (moneyness > 0.05) return 0.75;
    if (moneyness > 0) return 0.6;
    if (moneyness > -0.05) return 0.4;
    if (moneyness > -0.1) return 0.25;
    return 0.1;
  } else {
    if (moneyness < -0.1) return -0.9;
    if (moneyness < -0.05) return -0.75;
    if (moneyness < 0) return -0.6;
    if (moneyness < 0.05) return -0.4;
    if (moneyness < 0.1) return -0.25;
    return -0.1;
  }
}

function estimateGamma(strike, spot) {
  // Gamma peaks at ATM and falls off
  const moneyness = Math.abs(spot - strike) / spot;
  if (moneyness < 0.02) return 0.05;
  if (moneyness < 0.05) return 0.03;
  if (moneyness < 0.1) return 0.015;
  if (moneyness < 0.15) return 0.008;
  return 0.003;
}

// ─── Calculation: Max Pain ───────────────────────────────────────────────────

function calculateMaxPain(options) {
  let minPain = Infinity;
  let maxPainStrike = 0;

  for (const opt of options) {
    let totalPain = 0;

    for (const other of options) {
      // Call pain: call holders lose when price below their strike
      if (opt.strike > other.strike) {
        totalPain += (opt.strike - other.strike) * other.callOI;
      }
      // Put pain: put holders lose when price above their strike
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
    const callGEX = opt.callGamma * opt.callOI * 100 * spotPrice;
    const putGEX = -opt.putGamma * opt.putOI * 100 * spotPrice;
    const netGEX = callGEX + putGEX;
    gexByStrike.push({ strike: opt.strike, callGEX, putGEX, netGEX });
  }

  // Find resistance (highest positive GEX above price)
  const abovePrice = gexByStrike.filter(g => g.strike > spotPrice && g.netGEX > 0);
  const belowPrice = gexByStrike.filter(g => g.strike < spotPrice && g.netGEX > 0);

  const resistance = abovePrice.length > 0
    ? abovePrice.reduce((max, g) => g.netGEX > max.netGEX ? g : max).strike
    : null;

  const support = belowPrice.length > 0
    ? belowPrice.reduce((max, g) => g.netGEX > max.netGEX ? g : max).strike
    : null;

  // Zero GEX (flip point) - strike closest to zero net GEX
  const nearATM = gexByStrike.filter(g => Math.abs(g.strike - spotPrice) / spotPrice < 0.15);
  const zeroGEX = nearATM.length > 0
    ? nearATM.reduce((min, g) => Math.abs(g.netGEX) < Math.abs(min.netGEX) ? g : min).strike
    : null;

  // Net GEX sentiment
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
  let maxCallDeltaOI = 0;
  let callWallDelta = null;
  let maxPutDeltaOI = 0;
  let putWallDelta = null;

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

  // Also find OI-based walls
  let maxCallOI = 0;
  let callWallOI = null;
  let maxPutOI = 0;
  let putWallOI = null;

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

  return {
    callWallDelta,
    putWallDelta,
    callWallOI,
    putWallOI,
  };
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
  const highVolumeStrikes = volumeData
    .filter(v => v.volume > avgVolume * 1.5)
    .map(v => v.strike);

  const topVolumeStrikes = volumeData.slice(0, 5).map(v => ({
    strike: v.strike,
    volume: v.volume,
    callVolume: v.callVolume,
    putVolume: v.putVolume,
  }));

  return { poc, highVolumeStrikes, topVolumeStrikes };
}

// ─── Calculation: Biggest Strike Levels ─────────────────────────────────────

function calculateBiggestStrikes(options) {
  const oiData = options.map(o => ({
    strike: o.strike,
    totalOI: o.callOI + o.putOI,
    callOI: o.callOI,
    putOI: o.putOI,
  })).filter(o => o.totalOI > 0);

  oiData.sort((a, b) => b.totalOI - a.totalOI);

  const topOIStrikes = oiData.slice(0, 5).map(o => ({
    strike: o.strike,
    totalOI: o.totalOI,
    callOI: o.callOI,
    putOI: o.putOI,
  }));

  // Find highest individual call and put OI
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
  // Combine multiple signals for range estimation
  const levels = [
    deltaWalls.callWallDelta,
    deltaWalls.putWallDelta,
    deltaWalls.callWallOI,
    deltaWalls.putWallOI,
    gex.resistance,
    gex.support,
    maxPain,
  ].filter(v => v !== null && v !== undefined);

  const aboveLevels = levels.filter(l => l > spotPrice);
  const belowLevels = levels.filter(l => l < spotPrice);

  // Expected high = average of resistance levels, biased toward nearest
  const high = aboveLevels.length > 0
    ? aboveLevels.sort((a, b) => a - b)[0] // nearest resistance
    : spotPrice * 1.03;

  const low = belowLevels.length > 0
    ? belowLevels.sort((a, b) => b - a)[0] // nearest support
    : spotPrice * 0.97;

  return {
    low: +Math.min(low, spotPrice).toFixed(2),
    high: +Math.max(high, spotPrice).toFixed(2),
  };
}
