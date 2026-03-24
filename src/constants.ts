import { Settings, AssetClass } from './types';

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

export const ACCOUNT_COLORS = ['#0D6E6E', '#E07B54', '#5B7FD6', '#9333EA', '#DC2626', '#CA8A04'];

export function getAccountColor(index: number): string {
  return ACCOUNT_COLORS[index % ACCOUNT_COLORS.length];
}

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
  inputBg: '#F8F8F8',
  white: '#FFFFFF',
} as const;

export const DEFAULT_SETTINGS: Settings = {
  refreshInterval: 60,
  accentColor: '#0D6E6E',
};

export const SCHEMA_VERSION = 1;

export const ASSET_CLASS_LABELS: Record<string, AssetClass | 'all'> = {
  '전체': 'all',
  '미국': 'us_stock',
  '한국': 'kr_stock',
  '기타': 'cash',
};

export const ASSET_CLASS_OPTIONS = ['전체', '미국', '한국', '기타'];

export const POSITIVE_COLOR = '#16A34A';

export const POSITIVE_BG = '#E8F5E9';
export const NEGATIVE_BG = '#FFF0EB';

/** 거래 유형 한글 라벨 */
export const TRANSACTION_TYPE_LABELS: Record<string, string> = {
  buy: '매수',
  sell: '매도',
  opening_balance: '매수',
  adjustment: '매수',
};

/** 값의 부호에 따른 색상 반환 */
export function getStatusColors(value: number) {
  const positive = value >= 0;
  return {
    color: positive ? POSITIVE_COLOR : NEGATIVE_COLOR,
    bg: positive ? POSITIVE_BG : NEGATIVE_BG,
  };
}
