import { StockQuote, AssetClass } from '../types';

const PROXY_BASE = 'https://portfolio-cors-proxy.venaki.workers.dev';
const YAHOO_BASE = 'https://query1.finance.yahoo.com/v8/finance/chart';

// Known KOSDAQ tickers (add more as needed)
const KOSDAQ_TICKERS = ['096530'];

export function getYahooSymbol(ticker: string, assetClass: AssetClass): string {
  if (assetClass === 'kr_stock') {
    return KOSDAQ_TICKERS.includes(ticker) ? `${ticker}.KQ` : `${ticker}.KS`;
  }
  return ticker;
}

async function fetchYahooChart(symbol: string): Promise<any> {
  const { Platform } = require('react-native');

  if (Platform.OS === 'web') {
    // Web: use our Cloudflare Worker proxy
    const url = `${PROXY_BASE}/?symbol=${encodeURIComponent(symbol)}&range=1d&interval=1d`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Proxy error: ${res.status}`);
    return res.json();
  }

  // Native (iOS/Android): call Yahoo directly
  const url = `${YAHOO_BASE}/${symbol}?range=1d&interval=1d`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Yahoo error: ${res.status}`);
  return res.json();
}

export async function fetchQuotes(
  tickers: string[],
  tickerSymbolMap?: Record<string, string>,
): Promise<StockQuote[]> {
  console.log('[Yahoo] Fetching quotes for', tickers.length, 'tickers');
  const results: StockQuote[] = [];

  const promises = tickers.map(async (ticker) => {
    try {
      const yahooSymbol = tickerSymbolMap?.[ticker] ?? ticker;
      const data = await fetchYahooChart(yahooSymbol);

      const result = data?.chart?.result?.[0];
      if (!result) return null;

      const meta = result.meta;
      const price = meta.regularMarketPrice;
      const previousClose = meta.chartPreviousClose ?? meta.previousClose;

      return {
        symbol: ticker,
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

export async function fetchForexRate(): Promise<number> {
  console.log('[FX] Fetching USD/KRW rate');

  // 1) Open Exchange Rates (free, CORS OK)
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

  // 2) Yahoo Finance via proxy (web) or direct (native)
  try {
    const data = await fetchYahooChart('USDKRW=X');
    const rate = data?.chart?.result?.[0]?.meta?.regularMarketPrice;
    if (rate && rate > 0) {
      console.log('[FX] Yahoo success:', rate);
      return rate;
    }
  } catch (err: any) {
    console.warn('[FX] Yahoo forex failed:', err.message);
  }

  // 3) Frankfurter (free, CORS OK)
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
