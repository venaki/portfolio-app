import { StockQuote } from '../types';
import { FMP_BASE_URL } from '../constants';

export async function fetchQuotes(tickers: string[], apiKey: string): Promise<StockQuote[]> {
  const symbols = tickers.join(',');
  const url = `${FMP_BASE_URL}/quote/${symbols}?apikey=${apiKey}`;
  const res = await fetch(url);
  if (res.status === 429) throw new Error('QUOTA_EXCEEDED');
  if (res.status === 401 || res.status === 403) throw new Error('INVALID_API_KEY');
  if (!res.ok) throw new Error(`FMP_ERROR_${res.status}`);
  const data = await res.json();
  if (!Array.isArray(data)) throw new Error('INVALID_RESPONSE');
  return data.map((q: any) => ({
    symbol: q.symbol,
    name: q.name ?? q.symbol,
    price: q.price,
    change: q.change,
    changesPercentage: q.changesPercentage,
    previousClose: q.previousClose,
  }));
}

export async function fetchForexRate(apiKey: string): Promise<number> {
  const url = `${FMP_BASE_URL}/fx/USDKRW?apikey=${apiKey}`;
  const res = await fetch(url);
  if (res.status === 429) throw new Error('QUOTA_EXCEEDED');
  if (res.status === 401 || res.status === 403) throw new Error('INVALID_API_KEY');
  if (!res.ok) throw new Error(`FMP_ERROR_${res.status}`);
  const data = await res.json();
  if (!Array.isArray(data) || data.length === 0) throw new Error('INVALID_RESPONSE');
  const rate = parseFloat(data[0].bid) || parseFloat(data[0].ask);
  if (!rate || isNaN(rate)) throw new Error('INVALID_FOREX_RATE');
  return rate;
}
