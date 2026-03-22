import * as FileSystem from 'expo-file-system';
import { AppData } from '../types';
import { DEFAULT_SETTINGS, SCHEMA_VERSION } from '../constants';

const DATA_FILE = `${FileSystem.documentDirectory}portfolio-data.json`;

function createDefault(): AppData {
  return {
    schemaVersion: SCHEMA_VERSION,
    transactions: [],
    settings: { ...DEFAULT_SETTINGS },
  };
}

export async function loadAppData(): Promise<AppData> {
  try {
    const info = await FileSystem.getInfoAsync(DATA_FILE);
    if (!info.exists) return createDefault();
    const raw = await FileSystem.readAsStringAsync(DATA_FILE);
    const data: AppData = JSON.parse(raw);
    if (!data.schemaVersion) data.schemaVersion = SCHEMA_VERSION;
    if (!data.settings) data.settings = { ...DEFAULT_SETTINGS };
    if (!data.settings.accentColor) data.settings.accentColor = DEFAULT_SETTINGS.accentColor;
    if (!data.settings.refreshInterval) data.settings.refreshInterval = DEFAULT_SETTINGS.refreshInterval;
    return data;
  } catch {
    return createDefault();
  }
}

export async function saveAppData(data: AppData): Promise<void> {
  await FileSystem.writeAsStringAsync(DATA_FILE, JSON.stringify(data, null, 2));
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
