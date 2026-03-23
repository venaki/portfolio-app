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

// ── Platform I/O ──

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

// ── Migrations ──

const KR_TICKERS = ['005930', '034020', '035420', '096530'];

function migrateAssetClass(data: AppData): boolean {
  let changed = false;
  for (const tx of data.transactions) {
    if (!(tx as any).assetClass) {
      if (KR_TICKERS.includes(tx.ticker)) {
        (tx as any).assetClass = 'kr_stock';
        (tx as any).currency = 'KRW';
      } else {
        (tx as any).assetClass = 'us_stock';
        (tx as any).currency = 'USD';
      }
      changed = true;
    }
  }
  return changed;
}

function migrateKrStockOwner(data: AppData): boolean {
  let changed = false;
  for (const tx of data.transactions) {
    if (KR_TICKERS.includes(tx.ticker) && tx.owner === '본석') {
      (tx as any).owner = '연지';
      changed = true;
    }
  }
  return changed;
}

function migrateAccounts(data: AppData): boolean {
  if (!data.accounts) {
    const owners = [...new Set(data.transactions.map(t => t.owner))];
    data.accounts = owners.length > 0 ? owners : [];
    return true;
  }
  return false;
}

function ensureDefaults(data: AppData): void {
  if (!data.schemaVersion) data.schemaVersion = SCHEMA_VERSION;
  if (!data.settings) data.settings = { ...DEFAULT_SETTINGS };
  if (!data.settings.accentColor) data.settings.accentColor = DEFAULT_SETTINGS.accentColor;
  if (!data.settings.refreshInterval) data.settings.refreshInterval = DEFAULT_SETTINGS.refreshInterval;
}

function runMigrations(data: AppData): boolean {
  const m1 = migrateAssetClass(data);
  const m2 = migrateKrStockOwner(data);
  const m3 = migrateAccounts(data);
  return m1 || m2 || m3;
}

// ── Public API ──

export async function loadAppData(): Promise<AppData> {
  try {
    const raw = await readRaw();
    if (!raw) return createDefault();

    const data: AppData = JSON.parse(raw);
    ensureDefaults(data);

    if (runMigrations(data)) {
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

export async function resetAppData(): Promise<AppData> {
  const fresh = createDefault();
  await saveAppData(fresh);
  return fresh;
}
