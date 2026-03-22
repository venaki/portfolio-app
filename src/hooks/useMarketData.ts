import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { AppState } from 'react-native';
import { MarketData, Holding, StockQuote } from '../types';
import { fetchQuotes, fetchForexRate, getYahooSymbol } from '../api/fmp';
import { getApiKey } from '../storage/secureStore';

export function useMarketData(holdings: Holding[], refreshInterval: number) {
  const [data, setData] = useState<MarketData>({
    quotes: {},
    exchangeRate: 0,
    lastUpdated: null,
    isStale: false,
    isLoading: false,
    error: null,
  });
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Filter out cash holdings — they don't need price fetches
  const quotableHoldings = useMemo(
    () => holdings.filter(h => h.assetClass !== 'cash'),
    [holdings]
  );

  const tickerKey = quotableHoldings.map(h => h.ticker).sort().join(',');

  // Build unique tickers list and ticker→yahooSymbol map
  const { tickers, tickerSymbolMap } = useMemo(() => {
    const seen = new Map<string, string>(); // ticker → yahooSymbol
    for (const h of quotableHoldings) {
      if (!seen.has(h.ticker)) {
        seen.set(h.ticker, getYahooSymbol(h.ticker, h.assetClass));
      }
    }
    return {
      tickers: [...seen.keys()],
      tickerSymbolMap: Object.fromEntries(seen),
    };
  }, [tickerKey]);

  const refresh = useCallback(async () => {
    const apiKey = await getApiKey();
    if (!apiKey || tickers.length === 0) return;

    setData(prev => ({ ...prev, isLoading: true, error: null }));

    try {
      const [quotes, rate] = await Promise.all([
        fetchQuotes(tickers, apiKey, tickerSymbolMap),
        fetchForexRate(apiKey),
      ]);

      const quotesMap: Record<string, StockQuote> = {};
      quotes.forEach(q => { quotesMap[q.symbol] = q; });

      setData({
        quotes: quotesMap,
        exchangeRate: rate,
        lastUpdated: new Date().toISOString(),
        isStale: false,
        isLoading: false,
        error: null,
      });
    } catch (err: any) {
      setData(prev => ({
        ...prev,
        isStale: prev.lastUpdated !== null,
        isLoading: false,
        error: err.message,
      }));
    }
  }, [tickers, tickerSymbolMap]);

  // Auto-refresh
  useEffect(() => {
    refresh();
    intervalRef.current = setInterval(refresh, refreshInterval * 1000);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [refresh, refreshInterval]);

  // Resume on foreground
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') refresh();
    });
    return () => sub.remove();
  }, [refresh]);

  return { ...data, refresh };
}
