import { Platform } from 'react-native';
import { AppData } from '../types';
import { DEFAULT_SETTINGS, SCHEMA_VERSION } from '../constants';

const STORAGE_KEY = 'portfolio-data';

function createDefault(): AppData {
  return {
    schemaVersion: SCHEMA_VERSION,
    transactions: [],
    accounts: [],
    settings: { ...DEFAULT_SETTINGS },
  };
}

async function readRaw(): Promise<string | null> {
  if (Platform.OS === 'web') {
    return localStorage.getItem(STORAGE_KEY);
  }
  const FileSystem = await import('expo-file-system/legacy');
  const path = `${FileSystem.documentDirectory}${STORAGE_KEY}.json`;
  const info = await FileSystem.getInfoAsync(path);
  if (!info.exists) return null;
  return FileSystem.readAsStringAsync(path);
}

async function writeRaw(json: string): Promise<void> {
  if (Platform.OS === 'web') {
    localStorage.setItem(STORAGE_KEY, json);
    return;
  }
  const FileSystem = await import('expo-file-system/legacy');
  const path = `${FileSystem.documentDirectory}${STORAGE_KEY}.json`;
  await FileSystem.writeAsStringAsync(path, json);
}

export async function loadAppData(): Promise<AppData> {
  try {
    const raw = await readRaw();
    if (!raw) return createDefault();
    const data: AppData = JSON.parse(raw);
    if (!data.schemaVersion) data.schemaVersion = SCHEMA_VERSION;
    if (!data.settings) data.settings = { ...DEFAULT_SETTINGS };
    if (!data.settings.accentColor) data.settings.accentColor = DEFAULT_SETTINGS.accentColor;
    if (!data.settings.refreshInterval) data.settings.refreshInterval = DEFAULT_SETTINGS.refreshInterval;

    // Migration: add assetClass/currency to old transactions
    let migrated = false;
    const KR_TICKERS = ['005930', '034020', '035420', '096530'];
    for (const tx of data.transactions) {
      if (!(tx as any).assetClass) {
        if (KR_TICKERS.includes(tx.ticker)) {
          (tx as any).assetClass = 'kr_stock';
          (tx as any).currency = 'KRW';
        } else {
          (tx as any).assetClass = 'us_stock';
          (tx as any).currency = 'USD';
        }
        migrated = true;
      }
    }
    // Migration: fix KR stock owner 본석 → 연지
    for (const tx of data.transactions) {
      if (KR_TICKERS.includes(tx.ticker) && tx.owner === '본석') {
        (tx as any).owner = '연지';
        migrated = true;
      }
    }
    // Migration: extract unique owners as accounts if not present
    if (!data.accounts) {
      const owners = [...new Set(data.transactions.map(t => t.owner))];
      data.accounts = owners.length > 0 ? owners : [];
      migrated = true;
    }

    if (migrated) {
      await saveAppData(data);
    }

    return data;
  } catch {
    return createDefault();
  }
}

export async function saveAppData(data: AppData): Promise<void> {
  await writeRaw(JSON.stringify(data, null, 2));
}

export async function exportAppData(): Promise<string> {
  const data = await loadAppData();
  return JSON.stringify(data, null, 2);
}

export async function importAppData(json: string): Promise<AppData> {
  const data: AppData = JSON.parse(json);
  if (!data.schemaVersion || !data.transactions || !data.settings) {
    throw new Error('Invalid data format');
  }
  await saveAppData(data);
  return data;
}

export async function resetAppData(): Promise<AppData> {
  const fresh = createDefault();
  await saveAppData(fresh);
  return fresh;
}
