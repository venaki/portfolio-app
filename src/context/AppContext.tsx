import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
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
  market: MarketData & { refresh: () => Promise<void> };
  isLoading: boolean;
  addTransaction: (tx: Omit<Transaction, 'id'>) => Promise<void>;
  updateTransaction: (id: string, updates: Partial<Omit<Transaction, 'id'>>) => Promise<void>;
  deleteTransaction: (id: string) => Promise<void>;
  updateSettings: (updates: Partial<Settings>) => Promise<void>;
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
      if (data.transactions.length === 0) {
        data.transactions = SEED_TRANSACTIONS;
        await saveAppData(data);
      }
      setTransactions(data.transactions);
      setSettings(data.settings);
      setIsLoading(false);
    })();
  }, []);

  // Persist helper
  const persist = useCallback(async (txs: Transaction[], s: Settings) => {
    await saveAppData({ schemaVersion: SCHEMA_VERSION, transactions: txs, settings: s });
  }, []);

  const addTransaction = useCallback(async (tx: Omit<Transaction, 'id'>) => {
    const newTx: Transaction = { ...tx, id: uuid() };
    setTransactions(prev => {
      const updated = [...prev, newTx];
      persist(updated, settings);
      return updated;
    });
  }, [settings, persist]);

  const updateTransaction = useCallback(async (id: string, updates: Partial<Omit<Transaction, 'id'>>) => {
    setTransactions(prev => {
      const updated = prev.map(t => t.id === id ? { ...t, ...updates } : t);
      persist(updated, settings);
      return updated;
    });
  }, [settings, persist]);

  const deleteTransaction = useCallback(async (id: string) => {
    setTransactions(prev => {
      const updated = prev.filter(t => t.id !== id);
      persist(updated, settings);
      return updated;
    });
  }, [settings, persist]);

  const updateSettings = useCallback(async (updates: Partial<Settings>) => {
    const updated = { ...settings, ...updates };
    setSettings(updated);
    await persist(transactions, updated);
  }, [transactions, settings, persist]);

  const resetData = useCallback(async () => {
    const fresh = await resetStorage();
    setTransactions(fresh.transactions);
    setSettings(fresh.settings);
  }, []);

  const seedData = useCallback(async () => {
    setTransactions(prev => {
      const seeded = [...prev, ...SEED_TRANSACTIONS];
      persist(seeded, settings);
      return seeded;
    });
  }, [settings, persist]);

  const getAppDataJson = useCallback(async () => {
    const data: AppData = { schemaVersion: SCHEMA_VERSION, transactions, settings };
    return JSON.stringify(data, null, 2);
  }, [transactions, settings]);

  const importData = useCallback(async (json: string) => {
    const data: AppData = JSON.parse(json);
    if (!data.schemaVersion || !data.transactions || !data.settings) {
      throw new Error('Invalid data format');
    }
    setTransactions(data.transactions);
    setSettings(data.settings);
    await saveAppData(data);
  }, []);

  return (
    <AppContext.Provider value={{
      transactions, holdings, settings, market, isLoading,
      addTransaction, updateTransaction, deleteTransaction, updateSettings,
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
