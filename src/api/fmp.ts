import { StockQuote, AssetClass } from '../types';

// Yahoo Finance via public CORS proxy
const YAHOO_BASE = 'https://query1.finance.yahoo.com/v8/finance/chart';
const CORS_PROXIES = [
  'https://corsproxy.io/?',
  'https://api.allorigins.win/raw?url=',
];

// Known KOSDAQ tickers (add more as needed)
const KOSDAQ_TICKERS = ['096530'];

export function getYahooSymbol(ticker: string, assetClass: AssetClass): string {
  if (assetClass === 'kr_stock') {
    return KOSDAQ_TICKERS.includes(ticker) ? `${ticker}.KQ` : `${ticker}.KS`;
  }
  return ticker; // US stocks use ticker as-is
}

async function fetchWithProxy(url: string): Promise<any> {
  // Web: use CORS proxy. Native (iOS): try direct first.
  const { Platform } = require('react-native');
  const attempts = Platform.OS === 'web'
    ? CORS_PROXIES.map(proxy => `${proxy}${encodeURIComponent(url)}`)
    : [url, ...CORS_PROXIES.map(proxy => `${proxy}${encodeURIComponent(url)}`)];

  for (const attemptUrl of attempts) {
    try {
      const res = await fetch(attemptUrl);
      if (res.ok) {
        return res.json();
      }
    } catch {
      continue;
    }
  }
  throw new Error('ALL_PROXIES_FAILED');
}

/**
 * Fetch quotes for a list of tickers.
 * tickerSymbolMap: maps original ticker → Yahoo symbol (e.g., '035420' → '035420.KS')
 */
export async function fetchQuotes(
  tickers: string[],
  _apiKey: string,
  tickerSymbolMap?: Record<string, string>,
): Promise<StockQuote[]> {
  console.log('[Yahoo] Fetching quotes for', tickers.length, 'tickers');
  const results: StockQuote[] = [];

  const promises = tickers.map(async (ticker) => {
    try {
      const yahooSymbol = tickerSymbolMap?.[ticker] ?? ticker;
      const url = `${YAHOO_BASE}/${yahooSymbol}?range=1d&interval=1d`;
      const data = await fetchWithProxy(url);

      const result = data?.chart?.result?.[0];
      if (!result) return null;

      const meta = result.meta;
      const price = meta.regularMarketPrice;
      const previousClose = meta.chartPreviousClose ?? meta.previousClose;

      return {
        symbol: ticker, // Return keyed by original ticker, not Yahoo symbol
        name: meta.shortName ?? meta.longName ?? ticker,
        price,
        change: price - previousClose,
        changesPercentage: ((price - previousClose) / previousClose) * 100,
        previousClose,
      } as StockQuote;
    } catch (err: any) {
      console.warn(`[Yahoo] Failed to fetch ${ticker}:`, err.message);
      return null;
    }
  });

  const settled = await Promise.all(promises);
  for (const q of settled) {
    if (q) results.push(q);
  }

  if (results.length === 0) throw new Error('NO_QUOTES_AVAILABLE');
  console.log('[Yahoo] Success:', results.length, 'quotes');
  return results;
}

export async function fetchForexRate(_apiKey: string): Promise<number> {
  console.log('[FX] Fetching USD/KRW rate');

  // 1) Open Exchange Rates (free, no key)
  try {
    const res = await fetch('https://open.er-api.com/v6/latest/USD');
    if (res.ok) {
      const data = await res.json();
      const rate = data?.rates?.KRW;
      if (rate && rate > 0) {
        console.log('[FX] er-api success:', rate);
        return rate;
      }
    }
  } catch (err: any) {
    console.warn('[FX] er-api failed:', err.message);
  }

  // 2) Yahoo Finance USDKRW=X
  try {
    const url = `${YAHOO_BASE}/USDKRW=X?range=1d&interval=1d`;
    const data = await fetchWithProxy(url);
    const rate = data?.chart?.result?.[0]?.meta?.regularMarketPrice;
    if (rate && rate > 0) {
      console.log('[FX] Yahoo success:', rate);
      return rate;
    }
  } catch (err: any) {
    console.warn('[FX] Yahoo forex failed:', err.message);
  }

  // 3) Frankfurter (free, no key)
  try {
    const res = await fetch('https://api.frankfurter.app/latest?from=USD&to=KRW');
    if (res.ok) {
      const data = await res.json();
      const rate = data?.rates?.KRW;
      if (rate && rate > 0) {
        console.log('[FX] frankfurter success:', rate);
        return rate;
      }
    }
  } catch (err: any) {
    console.warn('[FX] frankfurter failed:', err.message);
  }

  console.warn('[FX] All forex APIs failed, using fallback 1450');
  return 1450;
}
