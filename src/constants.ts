import { Settings } from './types';

export const ACCENT_PRESETS = [
  { name: 'Teal', color: '#0D6E6E' },
  { name: 'Blue', color: '#2563EB' },
  { name: 'Purple', color: '#7C3AED' },
  { name: 'Green', color: '#16A34A' },
  { name: 'Orange', color: '#EA580C' },
  { name: 'Rose', color: '#E11D48' },
] as const;

export const OWNER_COLORS: Record<string, string> = {
  '본석': '#0D6E6E',
  '연지': '#E07B54',
  '나은': '#5B7FD6',
};

export const NEGATIVE_COLOR = '#E07B54';

export const COLORS = {
  background: '#FAFAFA',
  card: '#FFFFFF',
  border: '#E5E5E5',
  divider: '#F0F0F0',
  muted: '#F0F0F0',
  textPrimary: '#1A1A1A',
  textSecondary: '#666666',
  textTertiary: '#888888',
  textMuted: '#AAAAAA',
  textDisabled: '#BBBBBB',
} as const;

export const DEFAULT_SETTINGS: Settings = {
  refreshInterval: 60,
  accentColor: '#0D6E6E',
};

export const SCHEMA_VERSION = 1;

// FMP_BASE_URL은 src/api/fmp.ts 내부에서 직접 관리
