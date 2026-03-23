import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { AppData, Transaction, Holding, Settings, MarketData, StockQuote } from '../types';
import { loadAppData, saveAppData, resetAppData as resetStorage } from '../storage/appData';
import { replayTransactions } from '../engine/holdings';
import { useMarketData } from '../hooks/useMarketData';
import { DEFAULT_SETTINGS, SCHEMA_VERSION } from '../constants';
import { SEED_TRANSACTIONS } from '../seed';
import { v4 as uuid } from 'uuid';

interface AppContextType {
  transactions: Transaction[];
  holdings: Holding[];
  settings: Settings;
  accounts: string[];
  market: MarketData & { refresh: () => Promise<void> };
  isLoading: boolean;
  addTransaction: (tx: Omit<Transaction, 'id'>) => Promise<void>;
  updateTransaction: (id: string, updates: Partial<Omit<Transaction, 'id'>>) => Promise<void>;
  deleteTransaction: (id: string) => Promise<void>;
  updateSettings: (updates: Partial<Settings>) => Promise<void>;
  addAccount: (name: string) => Promise<void>;
  removeAccount: (name: string) => Promise<void>;
  resetData: () => Promise<void>;
  seedData: () => Promise<void>;
  getAppDataJson: () => Promise<string>;
  importData: (json: string) => Promise<void>;
}

const AppContext = createContext<AppContextType | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [holdings, setHoldings] = useState<Holding[]>([]);
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [accounts, setAccounts] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const market = useMarketData(holdings, settings.refreshInterval);

  // Recalculate holdings whenever transactions change
  useEffect(() => {
    setHoldings(replayTransactions(transactions));
  }, [transactions]);

  // Load data on mount (auto-seed on first launch)
  useEffect(() => {
    (async () => {
      const data = await loadAppData();
      setTransactions(data.transactions);
      setSettings(data.settings);
      setAccounts(data.accounts ?? []);
      setIsLoading(false);
    })();
  }, []);

  // Persist helper
  const persist = useCallback(async (txs: Transaction[], s: Settings, accs: string[]) => {
    await saveAppData({ schemaVersion: SCHEMA_VERSION, transactions: txs, accounts: accs, settings: s });
  }, []);

  const addTransaction = useCallback(async (tx: Omit<Transaction, 'id'>) => {
    const newTx: Transaction = { ...tx, id: uuid() };
    setTransactions(prev => {
      const updated = [...prev, newTx];
      persist(updated, settings, accounts);
      return updated;
    });
  }, [settings, accounts, persist]);

  const updateTransaction = useCallback(async (id: string, updates: Partial<Omit<Transaction, 'id'>>) => {
    setTransactions(prev => {
      const updated = prev.map(t => t.id === id ? { ...t, ...updates } : t);
      persist(updated, settings, accounts);
      return updated;
    });
  }, [settings, accounts, persist]);

  const deleteTransaction = useCallback(async (id: string) => {
    setTransactions(prev => {
      const updated = prev.filter(t => t.id !== id);
      persist(updated, settings, accounts);
      return updated;
    });
  }, [settings, accounts, persist]);

  const updateSettings = useCallback(async (updates: Partial<Settings>) => {
    const updated = { ...settings, ...updates };
    setSettings(updated);
    await persist(transactions, updated, accounts);
  }, [transactions, settings, accounts, persist]);

  const addAccount = useCallback(async (name: string) => {
    const trimmed = name.trim();
    if (!trimmed) return;
    setAccounts(prev => {
      if (prev.includes(trimmed)) return prev;
      const updated = [...prev, trimmed];
      persist(transactions, settings, updated);
      return updated;
    });
  }, [transactions, settings, persist]);

  const removeAccount = useCallback(async (name: string) => {
    setAccounts(prev => {
      const updated = prev.filter(a => a !== name);
      persist(transactions, settings, updated);
      return updated;
    });
  }, [transactions, settings, persist]);

  const resetData = useCallback(async () => {
    const fresh = await resetStorage();
    setTransactions(fresh.transactions);
    setAccounts(fresh.accounts ?? []);
    setSettings(fresh.settings);
  }, []);

  const seedData = useCallback(async () => {
    setTransactions(prev => {
      const seeded = [...prev, ...SEED_TRANSACTIONS];
      persist(seeded, settings, accounts);
      return seeded;
    });
  }, [settings, accounts, persist]);

  const getAppDataJson = useCallback(async () => {
    const data: AppData = { schemaVersion: SCHEMA_VERSION, transactions, accounts, settings };
    return JSON.stringify(data, null, 2);
  }, [transactions, accounts, settings]);

  const importData = useCallback(async (json: string) => {
    const raw = JSON.parse(json);
    if (!raw.transactions || !raw.settings) {
      throw new Error('Invalid data format');
    }
    // Save raw data, then reload through loadAppData which applies all migrations
    await saveAppData(raw);
    const migrated = await loadAppData();
    setTransactions(migrated.transactions);
    setAccounts(migrated.accounts ?? []);
    setSettings(migrated.settings);
  }, []);

  return (
    <AppContext.Provider value={{
      transactions, holdings, settings, accounts, market, isLoading,
      addTransaction, updateTransaction, deleteTransaction, updateSettings,
      addAccount, removeAccount,
      resetData, seedData, getAppDataJson, importData,
    }}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used within AppProvider');
  return ctx;
}
