# Portfolio Manager App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform (iOS + Web) portfolio management app with real-time stock prices, transaction-based holdings calculation, and per-owner asset tracking.

**Architecture:** Expo Router file-based routing with 4 tab screens. Transaction engine replays all transactions to derive holdings (moving-average method). FMP API for real-time quotes with stale-while-revalidate caching. Responsive layout: bottom pill tab bar (mobile) vs sidebar (PC).

**Tech Stack:** Expo SDK 53, React Native, TypeScript, Expo Router, expo-file-system, expo-secure-store, Financial Modeling Prep API

**Spec:** `/Users/venaki/Documents/Project/Financial App/SPEC.md`
**Design:** `/Users/venaki/Documents/Project/Financial App/financial-app-design.pen`

---

## File Structure

```
portfolio-app/
├── app/
│   ├── _layout.tsx                    # Root layout: load fonts, AppProvider wrapper
│   └── (tabs)/
│       ├── _layout.tsx                # Responsive navigator (tabs vs sidebar)
│       ├── index.tsx                  # Dashboard screen
│       ├── portfolio.tsx              # Portfolio screen
│       ├── history.tsx                # History screen
│       └── settings.tsx               # Settings screen
├── src/
│   ├── types.ts                       # All TypeScript types (Owner, Transaction, Holding, etc.)
│   ├── constants.ts                   # Accent color presets, default settings, owner colors
│   ├── seed.ts                        # Initial opening_balance transactions from Google Sheets
│   ├── engine/
│   │   ├── holdings.ts                # Transaction replay → holdings (moving average)
│   │   └── calculations.ts            # Profit/loss, KRW conversion, realized P&L
│   ├── storage/
│   │   ├── appData.ts                 # JSON file CRUD (expo-file-system)
│   │   └── secureStore.ts             # API key storage (expo-secure-store)
│   ├── api/
│   │   └── fmp.ts                     # FMP API client (batch quotes, forex)
│   ├── context/
│   │   └── AppContext.tsx              # Global state: transactions, holdings, market data, settings
│   ├── hooks/
│   │   ├── useMarketData.ts           # Auto-refresh quotes + forex, stale-while-revalidate
│   │   └── useResponsive.ts           # Mobile vs PC breakpoint detection
│   ├── components/
│   │   ├── AccountCard.tsx             # Per-owner asset summary card
│   │   ├── HoldingCard.tsx             # Holding card (mobile)
│   │   ├── HoldingRow.tsx              # Holding table row (PC)
│   │   ├── TransactionCard.tsx         # Transaction history card
│   │   ├── FilterTabs.tsx              # Segmented control (전체/본석/연지/나은)
│   │   ├── FilterChips.tsx             # Chip filter (전체/매수/매도)
│   │   ├── ColorPicker.tsx             # Accent color swatch selector
│   │   ├── AddTransactionModal.tsx     # Modal for adding buy/sell/opening_balance
│   │   └── TotalAssetCard.tsx          # Total asset summary with profit badge
│   └── utils/
│       └── format.ts                   # Number/currency/date formatting helpers
├── __tests__/
│   ├── engine/
│   │   ├── holdings.test.ts            # Holdings engine unit tests
│   │   └── calculations.test.ts        # Calculation formula unit tests
│   ├── storage/
│   │   └── appData.test.ts             # Storage serialization tests
│   └── utils/
│       └── format.test.ts              # Formatting tests
├── app.json
├── package.json
└── tsconfig.json
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `portfolio-app/` (entire Expo project)
- Create: `portfolio-app/app.json`
- Create: `portfolio-app/package.json`

- [ ] **Step 1: Create Expo project**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
npx create-expo-app@latest portfolio-app --template blank-typescript
```

- [ ] **Step 2: Install dependencies**

```bash
cd portfolio-app
npx expo install expo-file-system expo-secure-store expo-font @expo-google-fonts/newsreader @expo-google-fonts/jetbrains-mono @expo-google-fonts/inter expo-router expo-constants expo-linking expo-status-bar react-native-safe-area-context react-native-screens react-native-gesture-handler uuid
npm install --save-dev @types/uuid
```

- [ ] **Step 3: Configure app.json for Expo Router**

`app.json` — set scheme and plugins:
```json
{
  "expo": {
    "name": "Portfolio Manager",
    "slug": "portfolio-manager",
    "version": "1.0.0",
    "scheme": "portfolio",
    "platforms": ["ios", "web"],
    "plugins": ["expo-router", "expo-secure-store"],
    "web": {
      "bundler": "metro",
      "output": "single",
      "favicon": "./assets/favicon.png"
    }
  }
}
```

- [ ] **Step 4: Verify project runs**

```bash
npx expo start --web
```
Expected: Expo dev server starts, blank screen in browser.

- [ ] **Step 5: Initialize git and commit**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-app"
git init
git add .
git commit -m "chore: scaffold Expo project with dependencies"
```

---

## Task 2: Types, Constants, and Seed Data

**Files:**
- Create: `src/types.ts`
- Create: `src/constants.ts`
- Create: `src/seed.ts`
- Create: `src/utils/format.ts`
- Test: `__tests__/utils/format.test.ts`

- [ ] **Step 1: Define all TypeScript types**

`src/types.ts`:
```typescript
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
```

- [ ] **Step 2: Define constants**

`src/constants.ts`:
```typescript
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

export const FMP_BASE_URL = 'https://financialmodelingprep.com/api/v3';
```

- [ ] **Step 3: Create seed data**

`src/seed.ts`:
```typescript
import { Transaction, Owner } from './types';
import { v4 as uuid } from 'uuid';

const SEED_DATE = '2026-03-22T00:00:00.000Z';

function opening(owner: Owner, ticker: string, shares: number, price: number, exchangeRate: number): Transaction {
  return {
    id: uuid(),
    owner,
    ticker,
    type: 'opening_balance',
    shares,
    price,
    exchangeRate,
    executedAt: SEED_DATE,
    memo: '초기 시드 데이터',
  };
}

export const SEED_TRANSACTIONS: Transaction[] = [
  // 본석
  opening('본석', 'TSLA', 500, 318.01, 1450.51),
  opening('본석', 'TSLL', 2089, 16.86, 1430.00),
  opening('본석', 'TQQQ', 1200, 25.85, 1391.50),
  // 연지
  opening('연지', 'TSLA', 1053, 387.85, 1434.42),
  opening('연지', 'TSLL', 7300, 29.41, 1462.41),
  opening('연지', 'TQQQ', 406, 53.18, 1377.25),
  opening('연지', 'TSLY', 1000, 8.92, 1388.65),
  opening('연지', 'GOOGL', 4, 190.88, 1386.00),
  opening('연지', 'SGOV', 200, 100.51, 1450.50),
  opening('연지', 'NVDA', 14, 204.71, 1427.40),
  opening('연지', 'NFLX', 5, 88.74, 1473.60),
  opening('연지', 'MP', 4, 69.79, 1473.60),
  // 나은
  opening('나은', 'TQQQ', 1037, 38.10, 1467.16),
];
```

- [ ] **Step 4: Write formatting utils with tests**

`src/utils/format.ts`:
```typescript
export function formatKRW(value: number): string {
  return `₩${Math.round(value).toLocaleString('ko-KR')}`;
}

export function formatUSD(value: number): string {
  return `$${value.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function formatPercent(value: number): string {
  const sign = value >= 0 ? '+' : '';
  return `${sign}${value.toFixed(2)}%`;
}

export function formatShares(value: number): string {
  return value.toLocaleString('ko-KR');
}

export function formatDate(isoString: string): string {
  return isoString.slice(0, 10);
}

export function formatRelativeTime(isoString: string): string {
  const diff = Date.now() - new Date(isoString).getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return '방금 전';
  if (minutes < 60) return `${minutes}분 전`;
  const hours = Math.floor(minutes / 60);
  return `${hours}시간 전`;
}
```

`__tests__/utils/format.test.ts`:
```typescript
import { formatKRW, formatUSD, formatPercent, formatShares, formatRelativeTime } from '../../src/utils/format';

describe('formatKRW', () => {
  it('formats positive KRW', () => {
    expect(formatKRW(1301037659)).toBe('₩1,301,037,659');
  });
  it('rounds decimals', () => {
    expect(formatKRW(1234.56)).toBe('₩1,235');
  });
});

describe('formatUSD', () => {
  it('formats USD with 2 decimals', () => {
    expect(formatUSD(367.96)).toBe('$367.96');
  });
});

describe('formatPercent', () => {
  it('formats positive with + sign', () => {
    expect(formatPercent(15.71)).toBe('+15.71%');
  });
  it('formats negative', () => {
    expect(formatPercent(-3.24)).toBe('-3.24%');
  });
});

describe('formatShares', () => {
  it('formats with comma separator', () => {
    expect(formatShares(7300)).toBe('7,300');
  });
});

describe('formatPercent edge cases', () => {
  it('formats zero', () => {
    expect(formatPercent(0)).toBe('+0.00%');
  });
});

describe('formatKRW edge cases', () => {
  it('formats negative', () => {
    expect(formatKRW(-500000)).toBe('₩-500,000');
  });
});

describe('formatRelativeTime', () => {
  it('returns 방금 전 for recent time', () => {
    expect(formatRelativeTime(new Date().toISOString())).toBe('방금 전');
  });
});
```

- [ ] **Step 5: Run tests**

```bash
npx jest __tests__/utils/format.test.ts
```
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add src/ __tests__/
git commit -m "feat: add types, constants, seed data, and formatting utils"
```

---

## Task 3: Holdings Engine (TDD — Core Business Logic)

**Files:**
- Create: `src/engine/holdings.ts`
- Test: `__tests__/engine/holdings.test.ts`

- [ ] **Step 1: Write holdings engine tests**

`__tests__/engine/holdings.test.ts`:
```typescript
import { replayTransactions } from '../../src/engine/holdings';
import { Transaction, Holding } from '../../src/types';

function tx(overrides: Partial<Transaction> & Pick<Transaction, 'owner' | 'ticker' | 'type' | 'shares' | 'price' | 'exchangeRate'>): Transaction {
  return {
    id: Math.random().toString(),
    executedAt: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

describe('replayTransactions', () => {
  it('returns empty array for no transactions', () => {
    expect(replayTransactions([])).toEqual([]);
  });

  it('creates holding from opening_balance', () => {
    const txs = [tx({ owner: '본석', ticker: 'TSLA', type: 'opening_balance', shares: 500, price: 318.01, exchangeRate: 1450.51 })];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(1);
    expect(holdings[0]).toEqual({
      owner: '본석',
      ticker: 'TSLA',
      shares: 500,
      avgCost: 318.01,
      avgExchangeRate: 1450.51,
    });
  });

  it('calculates moving average on multiple buys', () => {
    const txs = [
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 200, price: 450, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(1);
    expect(holdings[0].shares).toBe(300);
    // (100*300 + 200*450) / 300 = 400
    expect(holdings[0].avgCost).toBeCloseTo(400, 2);
    // (100*1400 + 200*1500) / 300 = 1466.67
    expect(holdings[0].avgExchangeRate).toBeCloseTo(1466.67, 1);
  });

  it('sell reduces shares but keeps avgCost', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 500, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(400);
    expect(holdings[0].avgCost).toBe(300);
    expect(holdings[0].avgExchangeRate).toBe(1400);
  });

  it('removes holding when fully sold', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('separates holdings by owner', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400 }),
      tx({ owner: '연지', ticker: 'TSLA', type: 'buy', shares: 200, price: 400, exchangeRate: 1500 }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(2);
  });

  it('sorts transactions by executedAt before replay', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 50, price: 400, exchangeRate: 1500, executedAt: '2026-02-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 500, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(450);
  });

  it('oversell removes holding (sell > current shares)', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 150, price: 400, exchangeRate: 1500, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('sell without prior buy is silently ignored', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'sell', shares: 100, price: 400, exchangeRate: 1500 }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings).toHaveLength(0);
  });

  it('handles adjustment type', () => {
    const txs = [
      tx({ owner: '본석', ticker: 'TSLA', type: 'buy', shares: 100, price: 300, exchangeRate: 1400, executedAt: '2026-01-01T00:00:00Z' }),
      tx({ owner: '본석', ticker: 'TSLA', type: 'adjustment', shares: 50, price: 320, exchangeRate: 1420, executedAt: '2026-01-02T00:00:00Z' }),
    ];
    const holdings = replayTransactions(txs);
    expect(holdings[0].shares).toBe(150);
    // (100*300 + 50*320) / 150 = 306.67
    expect(holdings[0].avgCost).toBeCloseTo(306.67, 1);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
npx jest __tests__/engine/holdings.test.ts
```
Expected: FAIL — `replayTransactions` not found

- [ ] **Step 3: Implement holdings engine**

`src/engine/holdings.ts`:
```typescript
import { Transaction, Holding } from '../types';

export function replayTransactions(transactions: Transaction[]): Holding[] {
  const sorted = [...transactions].sort(
    (a, b) => new Date(a.executedAt).getTime() - new Date(b.executedAt).getTime()
  );

  const map = new Map<string, Holding>();

  for (const tx of sorted) {
    const key = `${tx.owner}::${tx.ticker}`;
    const existing = map.get(key);

    switch (tx.type) {
      case 'buy':
      case 'opening_balance':
      case 'adjustment': {
        if (existing) {
          const totalShares = existing.shares + tx.shares;
          const newAvgCost = (existing.shares * existing.avgCost + tx.shares * tx.price) / totalShares;
          const newAvgRate = (existing.shares * existing.avgExchangeRate + tx.shares * tx.exchangeRate) / totalShares;
          existing.shares = totalShares;
          existing.avgCost = newAvgCost;
          existing.avgExchangeRate = newAvgRate;
        } else {
          map.set(key, {
            owner: tx.owner,
            ticker: tx.ticker,
            shares: tx.shares,
            avgCost: tx.price,
            avgExchangeRate: tx.exchangeRate,
          });
        }
        break;
      }
      case 'sell': {
        if (existing) {
          existing.shares -= tx.shares;
          if (existing.shares <= 0) {
            map.delete(key);
          }
        }
        break;
      }
    }
  }

  return Array.from(map.values());
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
npx jest __tests__/engine/holdings.test.ts
```
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/engine/ __tests__/engine/
git commit -m "feat: implement holdings engine with moving average replay"
```

---

## Task 4: Calculations (TDD)

**Files:**
- Create: `src/engine/calculations.ts`
- Test: `__tests__/engine/calculations.test.ts`

- [ ] **Step 1: Write calculation tests**

`__tests__/engine/calculations.test.ts`:
```typescript
import {
  calcProfitUSD,
  calcProfitKRW,
  calcProfitPercentUSD,
  calcProfitPercentKRW,
  calcRealizedPL,
  calcTotalValueKRW,
} from '../../src/engine/calculations';
import { Holding } from '../../src/types';

const holding: Holding = {
  owner: '본석',
  ticker: 'TSLA',
  shares: 500,
  avgCost: 318.01,
  avgExchangeRate: 1450.51,
};

describe('calcProfitUSD', () => {
  it('calculates USD profit', () => {
    const result = calcProfitUSD(holding, 367.96);
    expect(result).toBeCloseTo((367.96 - 318.01) * 500, 0);
  });
});

describe('calcProfitPercentUSD', () => {
  it('calculates USD profit percent', () => {
    const result = calcProfitPercentUSD(holding, 367.96);
    expect(result).toBeCloseTo(((367.96 - 318.01) / 318.01) * 100, 1);
  });
});

describe('calcProfitKRW', () => {
  it('calculates KRW profit with exchange rate difference', () => {
    const currentRate = 1505.32;
    const evalKRW = 367.96 * 500 * currentRate;
    const costKRW = 318.01 * 500 * 1450.51;
    const result = calcProfitKRW(holding, 367.96, currentRate);
    expect(result).toBeCloseTo(evalKRW - costKRW, 0);
  });
});

describe('calcTotalValueKRW', () => {
  it('calculates total KRW value', () => {
    const result = calcTotalValueKRW(holding, 367.96, 1505.32);
    expect(result).toBeCloseTo(367.96 * 500 * 1505.32, 0);
  });
});

describe('calcProfitPercentKRW', () => {
  it('calculates KRW profit percent including exchange rate effect', () => {
    const result = calcProfitPercentKRW(holding, 367.96, 1505.32);
    const costKRW = 318.01 * 500 * 1450.51;
    const evalKRW = 367.96 * 500 * 1505.32;
    expect(result).toBeCloseTo(((evalKRW - costKRW) / costKRW) * 100, 1);
  });
});

describe('calcRealizedPL', () => {
  it('calculates realized P&L on sell', () => {
    const result = calcRealizedPL(100, 400, 1500, 300, 1400);
    // USD: (400 - 300) * 100 = 10000
    expect(result.usd).toBeCloseTo(10000, 0);
    // KRW: 400*100*1500 - 300*100*1400 = 60000000 - 42000000 = 18000000
    expect(result.krw).toBeCloseTo(18000000, 0);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
npx jest __tests__/engine/calculations.test.ts
```
Expected: FAIL

- [ ] **Step 3: Implement calculations**

`src/engine/calculations.ts`:
```typescript
import { Holding } from '../types';

export function calcProfitUSD(holding: Holding, currentPrice: number): number {
  return (currentPrice - holding.avgCost) * holding.shares;
}

export function calcProfitPercentUSD(holding: Holding, currentPrice: number): number {
  if (holding.avgCost === 0) return 0;
  return ((currentPrice - holding.avgCost) / holding.avgCost) * 100;
}

export function calcTotalValueKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  return currentPrice * holding.shares * currentRate;
}

export function calcCostKRW(holding: Holding): number {
  return holding.avgCost * holding.shares * holding.avgExchangeRate;
}

export function calcProfitKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  return calcTotalValueKRW(holding, currentPrice, currentRate) - calcCostKRW(holding);
}

export function calcProfitPercentKRW(holding: Holding, currentPrice: number, currentRate: number): number {
  const cost = calcCostKRW(holding);
  if (cost === 0) return 0;
  return ((calcTotalValueKRW(holding, currentPrice, currentRate) - cost) / cost) * 100;
}

export function calcDailyChangeKRW(
  holding: Holding,
  currentPrice: number,
  previousClose: number,
  currentRate: number,
): number {
  return (currentPrice - previousClose) * holding.shares * currentRate;
}

export function calcRealizedPL(
  sellShares: number,
  sellPrice: number,
  sellRate: number,
  avgCost: number,
  avgRate: number,
): { usd: number; krw: number } {
  return {
    usd: (sellPrice - avgCost) * sellShares,
    krw: sellPrice * sellShares * sellRate - avgCost * sellShares * avgRate,
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
npx jest __tests__/engine/calculations.test.ts
```
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/engine/calculations.ts __tests__/engine/calculations.test.ts
git commit -m "feat: implement profit/loss and realized P&L calculations"
```

---

## Task 5: Storage Layer

**Files:**
- Create: `src/storage/appData.ts`
- Create: `src/storage/secureStore.ts`

- [ ] **Step 1: Implement appData storage**

`src/storage/appData.ts`:
```typescript
import * as FileSystem from 'expo-file-system';
import { AppData, Transaction } from '../types';
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
    // Schema migration placeholder
    if (!data.schemaVersion) data.schemaVersion = SCHEMA_VERSION;
    if (!data.settings) data.settings = { ...DEFAULT_SETTINGS };
    if (!data.settings.accentColor) data.settings.accentColor = DEFAULT_SETTINGS.accentColor;
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
  if (!data.schemaVersion || !data.transactions) {
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
```

- [ ] **Step 2: Implement secure store for API key**

`src/storage/secureStore.ts`:
```typescript
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const API_KEY_KEY = 'fmp_api_key';

export async function getApiKey(): Promise<string | null> {
  if (Platform.OS === 'web') {
    return localStorage.getItem(API_KEY_KEY);
  }
  return SecureStore.getItemAsync(API_KEY_KEY);
}

export async function setApiKey(key: string): Promise<void> {
  if (Platform.OS === 'web') {
    localStorage.setItem(API_KEY_KEY, key);
    return;
  }
  await SecureStore.setItemAsync(API_KEY_KEY, key);
}

export async function deleteApiKey(): Promise<void> {
  if (Platform.OS === 'web') {
    localStorage.removeItem(API_KEY_KEY);
    return;
  }
  await SecureStore.deleteItemAsync(API_KEY_KEY);
}
```

- [ ] **Step 3: Commit**

```bash
git add src/storage/
git commit -m "feat: implement JSON file storage and secure API key storage"
```

---

## Task 6: FMP API Client

**Files:**
- Create: `src/api/fmp.ts`

- [ ] **Step 1: Implement FMP API client**

`src/api/fmp.ts`:
```typescript
import { StockQuote, ForexRate } from '../types';
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
```

- [ ] **Step 2: Commit**

```bash
git add src/api/
git commit -m "feat: implement FMP API client for quotes and forex"
```

---

## Task 7: App Context and Hooks

**Files:**
- Create: `src/context/AppContext.tsx`
- Create: `src/hooks/useMarketData.ts`
- Create: `src/hooks/useResponsive.ts`

- [ ] **Step 1: Implement responsive hook**

`src/hooks/useResponsive.ts`:
```typescript
import { useWindowDimensions } from 'react-native';

const BREAKPOINT = 768;

export function useResponsive() {
  const { width } = useWindowDimensions();
  return {
    isMobile: width < BREAKPOINT,
    isPC: width >= BREAKPOINT,
    width,
  };
}
```

- [ ] **Step 2: Implement market data hook**

`src/hooks/useMarketData.ts`:
```typescript
import { useState, useEffect, useCallback, useRef } from 'react';
import { AppState } from 'react-native';
import { MarketData, Holding } from '../types';
import { fetchQuotes, fetchForexRate } from '../api/fmp';
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

  const tickers = [...new Set(holdings.map(h => h.ticker))];

  const refresh = useCallback(async () => {
    const apiKey = await getApiKey();
    if (!apiKey || tickers.length === 0) return;

    setData(prev => ({ ...prev, isLoading: true, error: null }));

    try {
      const [quotes, rate] = await Promise.all([
        fetchQuotes(tickers, apiKey),
        fetchForexRate(apiKey),
      ]);

      const quotesMap: Record<string, any> = {};
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
  }, [tickers.join(',')]);

  // Auto-refresh
  useEffect(() => {
    refresh();
    intervalRef.current = setInterval(refresh, refreshInterval * 1000);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [refresh, refreshInterval]);

  // Pause when backgrounded
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') refresh();
    });
    return () => sub.remove();
  }, [refresh]);

  return { ...data, refresh };
}
```

- [ ] **Step 3: Implement AppContext**

`src/context/AppContext.tsx`:
```typescript
import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { AppData, Transaction, Holding, Settings, MarketData } from '../types';
import { loadAppData, saveAppData, resetAppData } from '../storage/appData';
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
        // First launch: seed with initial portfolio data
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

  const resetAllData = useCallback(async () => {
    const fresh = await resetAppData();
    setTransactions(fresh.transactions);
    setSettings(fresh.settings);
  }, []);

  const seedData = useCallback(async () => {
    const seeded = [...transactions, ...SEED_TRANSACTIONS];
    setTransactions(seeded);
    await persist(seeded, settings);
  }, [transactions, settings, persist]);

  const getAppDataJson = useCallback(async () => {
    const data: AppData = { schemaVersion: SCHEMA_VERSION, transactions, settings };
    return JSON.stringify(data, null, 2);
  }, [transactions, settings]);

  const importData = useCallback(async (json: string) => {
    const data: AppData = JSON.parse(json);
    setTransactions(data.transactions);
    setSettings(data.settings);
    await saveAppData(data);
  }, []);

  return (
    <AppContext.Provider value={{
      transactions, holdings, settings, market, isLoading,
      addTransaction, deleteTransaction, updateSettings,
      resetData: resetAllData, seedData, getAppDataJson, importData,
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
```

- [ ] **Step 4: Commit**

```bash
git add src/context/ src/hooks/
git commit -m "feat: implement AppContext, market data hook, and responsive hook"
```

---

## Task 8: Navigation Layout (Responsive Tabs / Sidebar)

**Files:**
- Create: `app/_layout.tsx`
- Create: `app/(tabs)/_layout.tsx`
- Create: `src/components/Sidebar.tsx`

- [ ] **Step 1: Root layout with font loading and provider**

`app/_layout.tsx`:
```typescript
import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { useFonts, Newsreader_400Regular, Newsreader_500Medium } from '@expo-google-fonts/newsreader';
import { JetBrainsMono_400Regular, JetBrainsMono_500Medium, JetBrainsMono_600SemiBold, JetBrainsMono_700Bold } from '@expo-google-fonts/jetbrains-mono';
import { Inter_400Regular, Inter_500Medium, Inter_600SemiBold } from '@expo-google-fonts/inter';
import * as SplashScreen from 'expo-splash-screen';
import { AppProvider } from '../src/context/AppContext';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    Newsreader_400Regular,
    Newsreader_500Medium,
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_600SemiBold,
    JetBrainsMono_700Bold,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
  });

  useEffect(() => {
    if (fontsLoaded) SplashScreen.hideAsync();
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  return (
    <AppProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
      </Stack>
    </AppProvider>
  );
}
```

- [ ] **Step 2: Implement Sidebar component**

`src/components/Sidebar.tsx`:
```typescript
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { usePathname, router } from 'expo-router';
import { useApp } from '../context/AppContext';
import { COLORS } from '../constants';

const NAV_ITEMS = [
  { label: '대시보드', path: '/', icon: '📊' },
  { label: '포트폴리오', path: '/portfolio', icon: '📈' },
  { label: '거래내역', path: '/history', icon: '🕐' },
  { label: '설정', path: '/settings', icon: '⚙️' },
];

export function Sidebar() {
  const pathname = usePathname();
  const { settings } = useApp();

  return (
    <View style={styles.container}>
      <View style={styles.logo}>
        <Text style={styles.logoText}>Portfolio</Text>
      </View>
      <View style={styles.nav}>
        {NAV_ITEMS.map(item => {
          const isActive = pathname === item.path || (item.path === '/' && pathname === '');
          return (
            <Pressable
              key={item.path}
              style={[styles.navItem, isActive && { backgroundColor: settings.accentColor }]}
              onPress={() => router.push(item.path as any)}
            >
              <Text style={[styles.navLabel, isActive && styles.navLabelActive]}>
                {item.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: 240,
    backgroundColor: COLORS.card,
    borderRightWidth: 1,
    borderRightColor: COLORS.border,
    paddingVertical: 32,
    paddingHorizontal: 20,
    gap: 32,
  },
  logo: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  logoText: { fontFamily: 'Newsreader_500Medium', fontSize: 22, color: COLORS.textPrimary },
  nav: { gap: 4 },
  navItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 14, borderRadius: 8, gap: 10 },
  navLabel: { fontFamily: 'Inter_500Medium', fontSize: 14, color: COLORS.textSecondary },
  navLabelActive: { fontFamily: 'Inter_600SemiBold', color: '#FFFFFF' },
});
```

- [ ] **Step 3: Tabs layout with responsive navigation**

`app/(tabs)/_layout.tsx`:
```typescript
import { Tabs } from 'expo-router';
import { View, StyleSheet } from 'react-native';
import { useResponsive } from '../../src/hooks/useResponsive';
import { useApp } from '../../src/context/AppContext';
import { Sidebar } from '../../src/components/Sidebar';
import { COLORS } from '../../src/constants';

export default function TabsLayout() {
  const { isMobile } = useResponsive();
  const { settings } = useApp();

  if (!isMobile) {
    // PC: Sidebar layout — Tabs still handles routing but we hide the tab bar
    return (
      <View style={styles.pcLayout}>
        <Sidebar />
        <View style={styles.pcContent}>
          <Tabs screenOptions={{
            headerShown: false,
            tabBarStyle: { display: 'none' },
          }}>
            <Tabs.Screen name="index" />
            <Tabs.Screen name="portfolio" />
            <Tabs.Screen name="history" />
            <Tabs.Screen name="settings" />
          </Tabs>
        </View>
      </View>
    );
  }

  // Mobile: Pill tab bar
  return (
    <Tabs screenOptions={{
      headerShown: false,
      tabBarActiveTintColor: '#FFFFFF',
      tabBarInactiveTintColor: '#AAAAAA',
      tabBarStyle: {
        backgroundColor: COLORS.card,
        borderTopWidth: 0,
        borderRadius: 36,
        marginHorizontal: 21,
        marginBottom: 21,
        height: 62,
        elevation: 8,
        shadowColor: '#000',
        shadowOpacity: 0.08,
        shadowRadius: 12,
        shadowOffset: { width: 0, height: 2 },
      },
      tabBarItemStyle: {
        borderRadius: 26,
        margin: 4,
      },
      tabBarActiveBackgroundColor: settings.accentColor,
      tabBarLabelStyle: {
        fontFamily: 'Inter_600SemiBold',
        fontSize: 10,
        textTransform: 'uppercase',
        letterSpacing: 0.5,
      },
    }}>
      <Tabs.Screen name="index" options={{ title: 'Home' }} />
      <Tabs.Screen name="portfolio" options={{ title: 'Portfolio' }} />
      <Tabs.Screen name="history" options={{ title: 'History' }} />
      <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  pcLayout: { flex: 1, flexDirection: 'row', backgroundColor: COLORS.background },
  pcContent: { flex: 1 },
});
```

- [ ] **Step 4: Create placeholder screens**

Create all 4 tab screen files with placeholder content:

`app/(tabs)/index.tsx`:
```typescript
import { View, Text } from 'react-native';
export default function Dashboard() {
  return <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}><Text>Dashboard</Text></View>;
}
```

`app/(tabs)/portfolio.tsx`, `app/(tabs)/history.tsx`, `app/(tabs)/settings.tsx` — same pattern with different text.

- [ ] **Step 5: Verify app runs with navigation**

```bash
npx expo start --web
```
Expected: PC shows sidebar + main area. Mobile shows tab bar.

- [ ] **Step 6: Commit**

```bash
git add app/ src/components/Sidebar.tsx
git commit -m "feat: implement responsive navigation (tabs + sidebar)"
```

---

## Task 9: Dashboard Screen

**Files:**
- Create: `src/components/TotalAssetCard.tsx`
- Create: `src/components/AccountCard.tsx`
- Modify: `app/(tabs)/index.tsx`

- [ ] **Step 1: Implement TotalAssetCard**

Full component with total value, profit badge, exchange rate, last updated.

- [ ] **Step 2: Implement AccountCard**

Per-owner card showing name (with color dot), total KRW, USD, profit percent.

- [ ] **Step 3: Build Dashboard screen**

Mobile: vertical scroll with TotalAssetCard (includes daily change KRW/%) → meta row (FX + update time) → "BY ACCOUNT" label → AccountCard × 3.
PC: wider layout with AccountCards in horizontal row.

Daily change is aggregated from `StockQuote.change * shares * currentRate` across all holdings.
Asset breakdown (종목별 비중) is deferred to a future iteration — not in v1 scope.

- [ ] **Step 4: Verify visually**

Compare with Pencil design. Check both mobile and PC layouts.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: implement Dashboard screen with total asset and account cards"
```

---

## Task 10: Portfolio Screen

**Files:**
- Create: `src/components/FilterTabs.tsx`
- Create: `src/components/HoldingCard.tsx`
- Create: `src/components/HoldingRow.tsx`
- Create: `src/components/AddTransactionModal.tsx`
- Modify: `app/(tabs)/portfolio.tsx`

- [ ] **Step 1: Implement FilterTabs** (segmented control: 전체/본석/연지/나은)

- [ ] **Step 2: Implement HoldingCard** (mobile: ticker, name, owner badge, shares, price, change, KRW value)

- [ ] **Step 3: Implement HoldingRow** (PC: table row with columns)

- [ ] **Step 4: Implement AddTransactionModal** (form: owner, ticker, type, shares, price, exchangeRate, date, memo)

- [ ] **Step 5: Build Portfolio screen**

Mobile: FilterTabs → HoldingCard list + add button.
PC: FilterTabs + add button → table header + HoldingRow list.

- [ ] **Step 6: Verify visually against design**

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: implement Portfolio screen with holdings and add transaction"
```

---

## Task 11: History Screen

**Files:**
- Create: `src/components/FilterChips.tsx`
- Create: `src/components/TransactionCard.tsx`
- Modify: `app/(tabs)/history.tsx`

- [ ] **Step 1: Implement FilterChips** (전체/매수/매도) + owner FilterTabs reuse (전체/본석/연지/나은)

Both filters combined: owner filter at top, then type chips below.

- [ ] **Step 2: Implement TransactionCard**

Badge colors: buy → green (#E8F5E9 + accent), sell → orange (#FFF0EB + #E07B54), opening_balance → gray (#F0F0F0 + #888888).
Sell cards show realized P&L.

- [ ] **Step 3: Build History screen**

Header + add button → FilterChips → date labels → TransactionCard list.

- [ ] **Step 4: Verify visually**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: implement History screen with transaction cards and filters"
```

---

## Task 12: Settings Screen

**Files:**
- Create: `src/components/ColorPicker.tsx`
- Modify: `app/(tabs)/settings.tsx`

- [ ] **Step 1: Implement ColorPicker** (6 circle swatches, selected has border + check)

- [ ] **Step 2: Build Settings screen**

Sections: APPEARANCE (ColorPicker) → API CONFIGURATION (key input) → DATA REFRESH (interval picker + usage display) → DATA MANAGEMENT (backup, restore, reset).

- [ ] **Step 3: Wire up all settings actions**

- accentColor change → updateSettings
- API key → setApiKey (secure store)
- Refresh interval → updateSettings
- Backup → share JSON file
- Restore → document picker → importData
- Reset → confirm dialog → resetData

- [ ] **Step 4: Verify visually**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: implement Settings screen with accent color, API key, and data management"
```

---

## Task 13: Pull-to-Refresh & Polish

**Files:**
- Modify: `app/(tabs)/index.tsx`
- Modify: `app/(tabs)/portfolio.tsx`
- Modify: `app/(tabs)/history.tsx`

- [ ] **Step 1: Add pull-to-refresh to Dashboard, Portfolio, History**

Wrap each screen's content in `<ScrollView refreshControl={<RefreshControl refreshing={market.isLoading} onRefresh={market.refresh} />}>`.

- [ ] **Step 2: Add stale indicator**

When `market.isStale`, show a subtle banner: "마지막 갱신: N분 전" using `formatRelativeTime`.

- [ ] **Step 3: Commit**

```bash
git add app/
git commit -m "feat: add pull-to-refresh and stale data indicator"
```

---

## Task 14: Integration Test & Polish

- [ ] **Step 1: Full flow test**

1. Fresh install → seed data loads → 13 opening_balance transactions
2. Enter FMP API key in settings → quotes start loading
3. Dashboard shows total assets with real-time prices
4. Portfolio filters work (전체/본석/연지/나은)
5. Add a buy transaction → holdings recalculate
6. Add a sell transaction → realized P&L shows in history
7. Change accent color → entire app updates
8. Backup → reset → restore → data intact

- [ ] **Step 2: Fix any visual/functional issues**

- [ ] **Step 3: Final commit**

```bash
git commit -m "chore: integration polish and bug fixes"
```
