export type Owner = '본석' | '연지' | '나은';

export type TransactionType = 'buy' | 'sell' | 'opening_balance' | 'adjustment';

export interface Transaction {
  id: string;
  owner: Owner;
  ticker: string;
  type: TransactionType;
  shares: number;
  price: number;
  exchangeRate: number;
  executedAt: string;
  memo?: string;
}

export interface Holding {
  owner: Owner;
  ticker: string;
  shares: number;
  avgCost: number;
  avgExchangeRate: number;
}

export interface Settings {
  refreshInterval: number;
  accentColor: string;
}

export interface AppData {
  schemaVersion: number;
  transactions: Transaction[];
  settings: Settings;
}

export interface StockQuote {
  symbol: string;
  name: string;
  price: number;
  change: number;
  changesPercentage: number;
  previousClose: number;
}

export interface ForexRate {
  ticker: string;
  bid: number;
  ask: number;
  changes: number;
}

export interface MarketData {
  quotes: Record<string, StockQuote>;
  exchangeRate: number;
  lastUpdated: string | null;
  isStale: boolean;
  isLoading: boolean;
  error: string | null;
}
