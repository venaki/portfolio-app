# Flutter + Google Sheets Migration — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter Web 프로젝트를 생성하고, Google Sign-In → Google Sheets 연결 → 거래 CRUD → 계산 엔진 → 대시보드/포트폴리오 화면까지 구현한다.

**Architecture:** Flutter Web + PWA, Google Sheets API v4 (batchGet/update), GOOGLEFINANCE 수식 기반 시세, Riverpod 상태 관리

**Tech Stack:** Flutter 3.x, Dart, google_sign_in, flutter_riverpod, http, shared_preferences, Material Design 3

**Spec:** `docs/superpowers/specs/2026-03-23-flutter-google-sheets-migration-design.md`

**Reference codebase:** `portfolio-app/` (현재 Expo/React Native 앱 — 계산 로직, 타입, 상수 참조용)

---

### Task 1: Flutter Web 프로젝트 생성 및 의존성 설정

**Files:**
- Create: `portfolio-flutter/pubspec.yaml`
- Create: `portfolio-flutter/lib/main.dart`
- Create: `portfolio-flutter/web/index.html`
- Create: `portfolio-flutter/web/manifest.json`

- [ ] **Step 1: Flutter 프로젝트 생성**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
flutter create --platforms web portfolio-flutter
```

- [ ] **Step 2: pubspec.yaml 의존성 추가**

`portfolio-flutter/pubspec.yaml`의 dependencies/dev_dependencies 수정:

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_sign_in: ^6.2.2
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  uuid: ^4.5.1
  url_launcher: ^6.3.1
  http: ^1.2.2
  shared_preferences: ^2.3.4
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  riverpod_generator: ^2.6.3
```

- [ ] **Step 3: 의존성 설치 및 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter pub get
flutter build web
```
Expected: 빌드 성공

- [ ] **Step 4: PWA manifest.json 설정**

`portfolio-flutter/web/manifest.json`:
```json
{
  "short_name": "Portfolio",
  "name": "Portfolio App",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#FAFAFA",
  "theme_color": "#0D6E6E",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

- [ ] **Step 5: web/index.html에 Google API 스크립트 추가**

`portfolio-flutter/web/index.html`의 `<head>`에 추가:
```html
<script src="https://accounts.google.com/gsi/client" async defer></script>
<script src="https://apis.google.com/js/api.js" async defer></script>
```

- [ ] **Step 6: 빌드 확인 후 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter build web
```
Expected: 빌드 성공

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/
git commit -m "feat: scaffold Flutter Web project with dependencies"
```

---

### Task 2: 데이터 모델 정의

**Files:**
- Create: `portfolio-flutter/lib/models/transaction.dart`
- Create: `portfolio-flutter/lib/models/holding.dart`
- Create: `portfolio-flutter/lib/models/stock_quote.dart`
- Create: `portfolio-flutter/lib/models/other_asset.dart`
- Create: `portfolio-flutter/lib/models/app_settings.dart`

**Reference:** `portfolio-app/src/types.ts`

- [ ] **Step 1: Transaction 모델**

`portfolio-flutter/lib/models/transaction.dart`:
```dart
enum TransactionType { buy, sell, openingBalance, adjustment }

enum Market { us, krx, kosdaq }

enum Currency { usd, krw }

class Transaction {
  final String id;
  final String date; // ISO 8601
  final String account;
  final TransactionType type;
  final String ticker;
  final Market market;
  final String name;
  final double shares;
  final double price;
  final Currency currency;
  final double exchangeRate;
  final String memo;

  const Transaction({
    required this.id,
    required this.date,
    required this.account,
    required this.type,
    required this.ticker,
    required this.market,
    required this.name,
    required this.shares,
    required this.price,
    required this.currency,
    required this.exchangeRate,
    this.memo = '',
  });

  /// Google Sheets 행 → Transaction
  factory Transaction.fromSheetRow(List<String> row) {
    return Transaction(
      id: row[0],
      date: row[1],
      account: row[2],
      type: _parseType(row[3]),
      ticker: row[4],
      market: _parseMarket(row[5]),
      name: row[6],
      shares: double.tryParse(row[7]) ?? 0,
      price: double.tryParse(row[8]) ?? 0,
      currency: row[9] == 'KRW' ? Currency.krw : Currency.usd,
      exchangeRate: double.tryParse(row[10]) ?? 0,
      memo: row.length > 11 ? row[11] : '',
    );
  }

  /// Transaction → Google Sheets 행
  List<String> toSheetRow() {
    return [
      id,
      date,
      account,
      type.toSheetValue(),
      ticker,
      market.toSheetValue(),
      name,
      shares.toString(),
      price.toString(),
      currency == Currency.krw ? 'KRW' : 'USD',
      exchangeRate.toString(),
      memo,
    ];
  }

  static TransactionType _parseType(String value) {
    switch (value) {
      case 'buy': return TransactionType.buy;
      case 'sell': return TransactionType.sell;
      case 'opening_balance': return TransactionType.openingBalance;
      case 'adjustment': return TransactionType.adjustment;
      default: return TransactionType.buy;
    }
  }

  static Market _parseMarket(String value) {
    switch (value) {
      case 'KRX': return Market.krx;
      case 'KOSDAQ': return Market.kosdaq;
      default: return Market.us;
    }
  }
}

extension TransactionTypeExt on TransactionType {
  String toSheetValue() {
    switch (this) {
      case TransactionType.buy: return 'buy';
      case TransactionType.sell: return 'sell';
      case TransactionType.openingBalance: return 'opening_balance';
      case TransactionType.adjustment: return 'adjustment';
    }
  }
}

extension MarketExt on Market {
  String toSheetValue() {
    switch (this) {
      case Market.us: return 'US';
      case Market.krx: return 'KRX';
      case Market.kosdaq: return 'KOSDAQ';
    }
  }
}
```

- [ ] **Step 2: Holding 모델**

`portfolio-flutter/lib/models/holding.dart`:
```dart
import 'transaction.dart';

class Holding {
  final String account;
  final String ticker;
  final Market market;
  final Currency currency;
  double shares;
  double avgCost;
  double avgExchangeRate;

  Holding({
    required this.account,
    required this.ticker,
    required this.market,
    required this.currency,
    required this.shares,
    required this.avgCost,
    required this.avgExchangeRate,
  });
}
```

- [ ] **Step 3: StockQuote 모델**

`portfolio-flutter/lib/models/stock_quote.dart`:
```dart
class StockQuote {
  final String ticker;
  final String name;
  final double price;
  final double changePct;
  final double closeYest;
  final String currency;

  const StockQuote({
    required this.ticker,
    required this.name,
    required this.price,
    required this.changePct,
    required this.closeYest,
    required this.currency,
  });

  /// Prices 시트 행 → StockQuote
  /// Row: [ticker, market, gf_key, price, name, changepct, closeyest, currency]
  factory StockQuote.fromSheetRow(List<String> row) {
    return StockQuote(
      ticker: row[0],
      name: row.length > 4 ? row[4] : '',
      price: double.tryParse(row[3]) ?? 0,
      changePct: double.tryParse(row[5]) ?? 0,
      closeYest: double.tryParse(row[6]) ?? 0,
      currency: row.length > 7 ? row[7] : 'USD',
    );
  }

  bool get hasError => price == 0;
}
```

- [ ] **Step 4: OtherAsset 모델**

`portfolio-flutter/lib/models/other_asset.dart`:
```dart
import 'transaction.dart';

enum AssetCategory { savings, bond, loan, cash, other }

class OtherAsset {
  final String id;
  final String account;
  final String name;
  final AssetCategory category;
  final double value;
  final Currency currency;
  final String date;
  final String memo;

  const OtherAsset({
    required this.id,
    required this.account,
    required this.name,
    required this.category,
    required this.value,
    required this.currency,
    required this.date,
    this.memo = '',
  });

  factory OtherAsset.fromSheetRow(List<String> row) {
    return OtherAsset(
      id: row[0],
      account: row[1],
      name: row[2],
      category: _parseCategory(row[3]),
      value: double.tryParse(row[4]) ?? 0,
      currency: row[5] == 'KRW' ? Currency.krw : Currency.usd,
      date: row[6],
      memo: row.length > 7 ? row[7] : '',
    );
  }

  List<String> toSheetRow() {
    return [id, account, name, category.toSheetValue(), value.toString(),
            currency == Currency.krw ? 'KRW' : 'USD', date, memo];
  }

  static AssetCategory _parseCategory(String value) {
    switch (value) {
      case 'savings': return AssetCategory.savings;
      case 'bond': return AssetCategory.bond;
      case 'loan': return AssetCategory.loan;
      case 'cash': return AssetCategory.cash;
      default: return AssetCategory.other;
    }
  }

  String get categoryLabel {
    switch (category) {
      case AssetCategory.savings: return '예금';
      case AssetCategory.bond: return '채권';
      case AssetCategory.loan: return '대출';
      case AssetCategory.cash: return '현금';
      case AssetCategory.other: return '기타';
    }
  }
}

extension AssetCategoryExt on AssetCategory {
  String toSheetValue() {
    switch (this) {
      case AssetCategory.savings: return 'savings';
      case AssetCategory.bond: return 'bond';
      case AssetCategory.loan: return 'loan';
      case AssetCategory.cash: return 'cash';
      case AssetCategory.other: return 'other';
    }
  }
}
```

- [ ] **Step 5: AppSettings 모델**

`portfolio-flutter/lib/models/app_settings.dart`:
```dart
class AppSettings {
  final List<String> accounts;
  final String baseCurrency;
  final String accentColor;
  final int refreshInterval;
  final int version;

  const AppSettings({
    this.accounts = const [],
    this.baseCurrency = 'KRW',
    this.accentColor = '#0D6E6E',
    this.refreshInterval = 60,
    this.version = 1,
  });

  factory AppSettings.fromSheetRows(List<List<String>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      if (row.length >= 2) map[row[0]] = row[1];
    }
    return AppSettings(
      accounts: (map['accounts'] ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      baseCurrency: map['base_currency'] ?? 'KRW',
      accentColor: map['accent_color'] ?? '#0D6E6E',
      refreshInterval: int.tryParse(map['refresh_interval'] ?? '60') ?? 60,
      version: int.tryParse(map['version'] ?? '1') ?? 1,
    );
  }

  List<List<String>> toSheetRows() {
    return [
      ['accounts', accounts.join(',')],
      ['base_currency', baseCurrency],
      ['accent_color', accentColor],
      ['refresh_interval', refreshInterval.toString()],
      ['version', version.toString()],
    ];
  }

  AppSettings copyWith({
    List<String>? accounts,
    String? baseCurrency,
    String? accentColor,
    int? refreshInterval,
    int? version,
  }) {
    return AppSettings(
      accounts: accounts ?? this.accounts,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      accentColor: accentColor ?? this.accentColor,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      version: version ?? this.version,
    );
  }
}
```

- [ ] **Step 6: 빌드 확인 후 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```
Expected: No issues found

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/models/
git commit -m "feat: add data models (Transaction, Holding, StockQuote, OtherAsset, AppSettings)"
```

---

### Task 3: 유틸리티 및 상수

**Files:**
- Create: `portfolio-flutter/lib/utils/format.dart`
- Create: `portfolio-flutter/lib/utils/constants.dart`

**Reference:** `portfolio-app/src/utils/format.ts`, `portfolio-app/src/constants.ts`

- [ ] **Step 1: format.dart 작성**

`portfolio-flutter/lib/utils/format.dart`:
```dart
import 'package:intl/intl.dart';

final _krwFormat = NumberFormat('#,###', 'ko_KR');
final _usdFormat = NumberFormat('#,##0.00', 'en_US');

String formatKRW(double value) {
  final abs = value.abs().round();
  final formatted = _krwFormat.format(abs);
  return value < 0 ? '-₩$formatted' : '₩$formatted';
}

String formatUSD(double value) {
  final abs = value.abs();
  final formatted = _usdFormat.format(abs);
  return value < 0 ? '-\$$formatted' : '\$$formatted';
}

String formatPercent(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String formatShares(double value) {
  return _krwFormat.format(value);
}

String formatDate(String isoString) {
  return isoString.length >= 10 ? isoString.substring(0, 10) : isoString;
}

String formatRelativeTime(String isoString) {
  final diff = DateTime.now().difference(DateTime.parse(isoString));
  final minutes = diff.inMinutes;
  if (minutes < 1) return '방금 전';
  if (minutes < 60) return '$minutes분 전';
  final hours = diff.inHours;
  if (hours < 24) return '$hours시간 전';
  return '${diff.inDays}일 전';
}
```

- [ ] **Step 2: constants.dart 작성**

`portfolio-flutter/lib/utils/constants.dart`:
```dart
import 'package:flutter/material.dart';

class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

const accentPresets = [
  AccentPreset('Teal', Color(0xFF0D6E6E)),
  AccentPreset('Blue', Color(0xFF2563EB)),
  AccentPreset('Purple', Color(0xFF7C3AED)),
  AccentPreset('Green', Color(0xFF16A34A)),
  AccentPreset('Orange', Color(0xFFEA580C)),
  AccentPreset('Rose', Color(0xFFE11D48)),
];

const accountColors = [
  Color(0xFF0D6E6E),
  Color(0xFFE07B54),
  Color(0xFF5B7FD6),
  Color(0xFF9333EA),
  Color(0xFFDC2626),
  Color(0xFFCA8A04),
];

Color getAccountColor(int index) => accountColors[index % accountColors.length];

const positiveColor = Color(0xFF16A34A);
const negativeColor = Color(0xFFE07B54);

const fallbackExchangeRate = 1450.0;

const corsProxyBase = 'https://portfolio-cors-proxy.venaki.workers.dev';

const defaultAccentColorHex = '#0D6E6E';

Color hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 7) buffer.write('FF');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
```

- [ ] **Step 3: 빌드 확인 후 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/utils/
git commit -m "feat: add utility functions (format, constants)"
```

---

### Task 4: 계산 엔진 + 테스트

**Files:**
- Create: `portfolio-flutter/lib/engine/holdings_engine.dart`
- Create: `portfolio-flutter/lib/engine/calculations.dart`
- Create: `portfolio-flutter/test/engine/holdings_engine_test.dart`
- Create: `portfolio-flutter/test/engine/calculations_test.dart`

**Reference:** `portfolio-app/src/engine/holdings.ts`, `portfolio-app/src/engine/calculations.ts`

- [ ] **Step 1: holdings_engine.dart 작성**

`portfolio-flutter/lib/engine/holdings_engine.dart`:
```dart
import '../models/transaction.dart';
import '../models/holding.dart';

List<Holding> replayTransactions(List<Transaction> transactions) {
  final sorted = List<Transaction>.from(transactions)
    ..sort((a, b) => a.date.compareTo(b.date));

  final map = <String, Holding>{};

  for (final tx in sorted) {
    final key = '${tx.account}::${tx.ticker}';
    final existing = map[key];

    switch (tx.type) {
      case TransactionType.buy:
      case TransactionType.openingBalance:
      case TransactionType.adjustment:
        if (existing != null) {
          final totalShares = existing.shares + tx.shares;
          existing.avgCost =
              (existing.shares * existing.avgCost + tx.shares * tx.price) / totalShares;
          existing.avgExchangeRate =
              (existing.shares * existing.avgExchangeRate + tx.shares * tx.exchangeRate) / totalShares;
          existing.shares = totalShares;
        } else {
          map[key] = Holding(
            account: tx.account,
            ticker: tx.ticker,
            market: tx.market,
            currency: tx.currency,
            shares: tx.shares,
            avgCost: tx.price,
            avgExchangeRate: tx.exchangeRate,
          );
        }
        break;
      case TransactionType.sell:
        if (existing != null) {
          existing.shares -= tx.shares;
          if (existing.shares <= 0) {
            map.remove(key);
          }
        }
        break;
    }
  }

  return map.values.toList();
}
```

- [ ] **Step 2: holdings_engine 테스트 작성**

`portfolio-flutter/test/engine/holdings_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/engine/holdings_engine.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  group('replayTransactions', () {
    test('single buy creates holding', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 10);
      expect(holdings[0].avgCost, 300);
      expect(holdings[0].avgExchangeRate, 1400);
    });

    test('two buys calculates weighted average', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
        Transaction(
          id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd,
          exchangeRate: 1500,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 20);
      expect(holdings[0].avgCost, 350); // (10*300 + 10*400) / 20
      expect(holdings[0].avgExchangeRate, 1450);
    });

    test('sell reduces shares', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
        Transaction(
          id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 400, currency: Currency.usd,
          exchangeRate: 1500,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 5);
      expect(holdings[0].avgCost, 300); // sell doesn't change avgCost
    });

    test('sell all removes holding', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
        Transaction(
          id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd,
          exchangeRate: 1500,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 0);
    });

    test('different accounts are separate', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
        Transaction(
          id: '2', date: '2025-01-01', account: '연지',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 350, currency: Currency.usd,
          exchangeRate: 1450,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 2);
    });
  });
}
```

- [ ] **Step 3: 테스트 실행 — 실패 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter test test/engine/holdings_engine_test.dart
```
Expected: PASS (코드가 이미 작성된 TDD 아닌 verify-after-write 방식)

- [ ] **Step 4: calculations.dart 작성**

`portfolio-flutter/lib/engine/calculations.dart`:
```dart
import '../models/holding.dart';
import '../models/transaction.dart';

double calcProfitUSD(Holding holding, double currentPrice) {
  return (currentPrice - holding.avgCost) * holding.shares;
}

double calcProfitPercentUSD(Holding holding, double currentPrice) {
  if (holding.avgCost == 0) return 0;
  return ((currentPrice - holding.avgCost) / holding.avgCost) * 100;
}

double calcTotalValueKRW(Holding holding, double currentPrice, double currentRate) {
  if (holding.currency == Currency.krw) {
    return currentPrice * holding.shares;
  }
  return currentPrice * holding.shares * currentRate;
}

double calcCostKRW(Holding holding) {
  if (holding.currency == Currency.krw) {
    return holding.avgCost * holding.shares;
  }
  return holding.avgCost * holding.shares * holding.avgExchangeRate;
}

double calcProfitKRW(Holding holding, double currentPrice, double currentRate) {
  return calcTotalValueKRW(holding, currentPrice, currentRate) - calcCostKRW(holding);
}

double calcProfitPercentKRW(Holding holding, double currentPrice, double currentRate) {
  final cost = calcCostKRW(holding);
  if (cost == 0) return 0;
  return ((calcTotalValueKRW(holding, currentPrice, currentRate) - cost) / cost) * 100;
}

double calcDailyChangeKRW(
  Holding holding, double currentPrice, double closeYest, double currentRate,
) {
  if (holding.currency == Currency.krw) {
    return (currentPrice - closeYest) * holding.shares;
  }
  return (currentPrice - closeYest) * holding.shares * currentRate;
}

({double usd, double krw}) calcRealizedPL(
  double sellShares, double sellPrice, double sellRate,
  double avgCost, double avgRate,
) {
  return (
    usd: (sellPrice - avgCost) * sellShares,
    krw: sellPrice * sellShares * sellRate - avgCost * sellShares * avgRate,
  );
}
```

- [ ] **Step 5: calculations 테스트 작성**

`portfolio-flutter/test/engine/calculations_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/engine/calculations.dart';
import 'package:portfolio_flutter/models/holding.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  final usdHolding = Holding(
    account: '본석', ticker: 'TSLA', market: Market.us,
    currency: Currency.usd, shares: 10, avgCost: 300, avgExchangeRate: 1400,
  );

  final krwHolding = Holding(
    account: '본석', ticker: '005930', market: Market.krx,
    currency: Currency.krw, shares: 100, avgCost: 70000, avgExchangeRate: 0,
  );

  group('calcProfitUSD', () {
    test('positive profit', () {
      expect(calcProfitUSD(usdHolding, 350), 500); // (350-300)*10
    });
    test('negative profit', () {
      expect(calcProfitUSD(usdHolding, 250), -500);
    });
  });

  group('calcTotalValueKRW', () {
    test('USD holding', () {
      expect(calcTotalValueKRW(usdHolding, 350, 1500), 5250000); // 350*10*1500
    });
    test('KRW holding', () {
      expect(calcTotalValueKRW(krwHolding, 80000, 1500), 8000000); // 80000*100
    });
  });

  group('calcCostKRW', () {
    test('USD holding uses avgExchangeRate', () {
      expect(calcCostKRW(usdHolding), 4200000); // 300*10*1400
    });
    test('KRW holding', () {
      expect(calcCostKRW(krwHolding), 7000000); // 70000*100
    });
  });

  group('calcProfitKRW', () {
    test('positive', () {
      expect(calcProfitKRW(usdHolding, 350, 1500), 1050000); // 5250000-4200000
    });
  });

  group('calcDailyChangeKRW', () {
    test('USD holding', () {
      expect(calcDailyChangeKRW(usdHolding, 350, 340, 1500), 150000); // (350-340)*10*1500
    });
    test('KRW holding', () {
      expect(calcDailyChangeKRW(krwHolding, 80000, 78000, 1500), 200000); // (80000-78000)*100
    });
  });
}
```

- [ ] **Step 6: 전체 테스트 실행**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter test
```
Expected: All tests pass

- [ ] **Step 7: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/engine/ portfolio-flutter/test/engine/
git commit -m "feat: add calculation engine with tests (holdings replay, profit/loss)"
```

---

### Task 5: Auth Service (Google Sign-In)

**Files:**
- Create: `portfolio-flutter/lib/services/auth_service.dart`

- [ ] **Step 1: auth_service.dart 작성**

`portfolio-flutter/lib/services/auth_service.dart`:
```dart
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  final _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// 자동 로그인 시도 (이전 세션 복원)
  Future<GoogleSignInAccount?> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  /// Google Sign-In 팝업
  Future<GoogleSignInAccount?> signIn() async {
    _currentUser = await _googleSignIn.signIn();
    return _currentUser;
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Sheets API용 인증 헤더 가져오기
  Future<Map<String, String>> getAuthHeaders() async {
    final user = _currentUser;
    if (user == null) throw Exception('Not signed in');
    return await user.authHeaders;
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```

- [ ] **Step 3: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/services/auth_service.dart
git commit -m "feat: add Google Sign-In auth service"
```

---

### Task 6: Sheets Service (Google Sheets API CRUD)

**Files:**
- Create: `portfolio-flutter/lib/services/sheets_service.dart`

**Spec reference:** 섹션 3 (Data Structure), 섹션 5 (Spreadsheet Management), 섹션 8 (Data Sync)

- [ ] **Step 1: sheets_service.dart 작성**

`portfolio-flutter/lib/services/sheets_service.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';

class SheetsService {
  static const _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';

  final Future<Map<String, String>> Function() _getAuthHeaders;
  String? _spreadsheetId;

  SheetsService({required Future<Map<String, String>> Function() getAuthHeaders})
      : _getAuthHeaders = getAuthHeaders;

  String? get spreadsheetId => _spreadsheetId;

  void setSpreadsheetId(String id) => _spreadsheetId = id;

  // ─── Spreadsheet 생성 ───

  /// 새 스프레드시트 생성 + 4개 시트 + 헤더 + 환율 행
  Future<String> createSpreadsheet() async {
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    // 1. 스프레드시트 생성 (4개 시트)
    final createRes = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode({
        'properties': {'title': 'Portfolio DB'},
        'sheets': [
          {'properties': {'title': 'Transactions'}},
          {'properties': {'title': 'Prices'}},
          {'properties': {'title': 'OtherAssets'}},
          {'properties': {'title': 'Settings'}},
        ],
      }),
    );
    if (createRes.statusCode != 200) {
      throw Exception('Failed to create spreadsheet: ${createRes.body}');
    }
    final created = jsonDecode(createRes.body);
    final id = created['spreadsheetId'] as String;
    _spreadsheetId = id;

    // 2. 헤더 + 초기 데이터 삽입
    await _batchUpdate(id, headers, [
      _valueRange('Transactions!A1:L1', [
        ['id', 'date', 'account', 'type', 'ticker', 'market', 'name', 'shares', 'price', 'currency', 'exchangeRate', 'memo']
      ]),
      _valueRange('Prices!A1:H1', [
        ['ticker', 'market', 'googlefinance_key', 'price', 'name', 'changepct', 'closeyest', 'currency']
      ]),
      // 환율 행 (수식은 userEnteredValue로 별도 삽입)
      _valueRange('OtherAssets!A1:H1', [
        ['id', 'account', 'name', 'category', 'value', 'currency', 'date', 'memo']
      ]),
      _valueRange('Settings!A1:B5', [
        ['accounts', ''],
        ['base_currency', 'KRW'],
        ['accent_color', '#0D6E6E'],
        ['refresh_interval', '60'],
        ['version', '1'],
      ]),
    ]);

    // 3. Prices 시트에 환율 GOOGLEFINANCE 수식 삽입
    await _insertPriceFormula(id, headers, 'USDKRW', 'FX', 'CURRENCY:USDKRW', 'KRW');

    return id;
  }

  // ─── BatchGet (초기 로드) ───

  /// 4개 시트를 한 번에 읽기
  Future<({
    List<Transaction> transactions,
    List<StockQuote> quotes,
    double exchangeRate,
    List<OtherAsset> otherAssets,
    AppSettings settings,
  })> loadAll() async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final ranges = [
      'Transactions!A2:L',
      'Prices!A2:H',
      'OtherAssets!A2:H',
      'Settings!A1:B',
    ].map(Uri.encodeComponent).join('&ranges=');

    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values:batchGet?ranges=$ranges'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('batchGet failed: ${res.body}');

    final data = jsonDecode(res.body);
    final valueRanges = data['valueRanges'] as List;

    // Transactions
    final txRows = _getRows(valueRanges[0]);
    final transactions = txRows.map((r) => Transaction.fromSheetRow(_padRow(r, 12))).toList();

    // Prices → quotes + exchangeRate
    final priceRows = _getRows(valueRanges[1]);
    final quotes = <StockQuote>[];
    double exchangeRate = 1450;
    for (final row in priceRows) {
      final padded = _padRow(row, 8);
      if (padded[1] == 'FX') {
        exchangeRate = double.tryParse(padded[3]) ?? 1450;
      } else {
        quotes.add(StockQuote.fromSheetRow(padded));
      }
    }

    // OtherAssets
    final oaRows = _getRows(valueRanges[2]);
    final otherAssets = oaRows.map((r) => OtherAsset.fromSheetRow(_padRow(r, 8))).toList();

    // Settings
    final settingsRows = _getRows(valueRanges[3]);
    final settings = AppSettings.fromSheetRows(settingsRows.map((r) => _padRow(r, 2)).toList());

    return (
      transactions: transactions,
      quotes: quotes,
      exchangeRate: exchangeRate,
      otherAssets: otherAssets,
      settings: settings,
    );
  }

  // ─── Prices 시트 읽기 (시세 갱신용) ───

  Future<({List<StockQuote> quotes, double exchangeRate})> loadPrices() async {
    _ensureId();
    final headers = await _getAuthHeaders();
    final res = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent("Prices!A2:H")}'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('loadPrices failed: ${res.body}');

    final data = jsonDecode(res.body);
    final rows = _getRows(data);
    final quotes = <StockQuote>[];
    double exchangeRate = 1450;
    for (final row in rows) {
      final padded = _padRow(row, 8);
      if (padded[1] == 'FX') {
        exchangeRate = double.tryParse(padded[3]) ?? 1450;
      } else {
        quotes.add(StockQuote.fromSheetRow(padded));
      }
    }
    return (quotes: quotes, exchangeRate: exchangeRate);
  }

  // ─── Transaction CRUD ───

  Future<void> addTransaction(Transaction tx) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/Transactions!A:L:append?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [tx.toSheetRow()]}),
    );
  }

  Future<void> updateTransaction(Transaction tx, int rowIndex) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    final range = 'Transactions!A${rowIndex + 2}:L${rowIndex + 2}'; // +2: header + 0-index
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent(range)}?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': [tx.toSheetRow()]}),
    );
  }

  Future<void> deleteTransaction(int rowIndex) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    // 시트 ID 가져오기
    final metaRes = await http.get(
      Uri.parse('$_baseUrl/$_spreadsheetId?fields=sheets.properties'),
      headers: headers,
    );
    final meta = jsonDecode(metaRes.body);
    final sheets = meta['sheets'] as List;
    final txSheetId = (sheets.firstWhere(
      (s) => s['properties']['title'] == 'Transactions',
    ))['properties']['sheetId'];

    await http.post(
      Uri.parse('$_baseUrl/$_spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': txSheetId,
                'dimension': 'ROWS',
                'startIndex': rowIndex + 1, // +1 for header
                'endIndex': rowIndex + 2,
              }
            }
          }
        ]
      }),
    );
  }

  // ─── Prices 시트에 GOOGLEFINANCE 수식 행 추가 ───

  Future<void> addPriceRow(String ticker, String market, String currency) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    String gfKey;
    switch (market) {
      case 'KRX': gfKey = 'KRX:$ticker'; break;
      case 'KOSDAQ': gfKey = 'KOSDAQ:$ticker'; break;
      default: gfKey = ticker; break;
    }

    await _insertPriceFormula(_spreadsheetId!, headers, ticker, market, gfKey, currency);
  }

  // ─── Settings 업데이트 ───

  Future<void> saveSettings(AppSettings settings) async {
    _ensureId();
    final headers = await _getAuthHeaders();
    headers['Content-Type'] = 'application/json';
    await http.put(
      Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent("Settings!A1:B5")}?valueInputOption=RAW'),
      headers: headers,
      body: jsonEncode({'values': settings.toSheetRows()}),
    );
  }

  // ─── Private helpers ───

  void _ensureId() {
    if (_spreadsheetId == null) throw Exception('Spreadsheet ID not set');
  }

  Future<void> _insertPriceFormula(
    String ssId, Map<String, String> headers,
    String ticker, String market, String gfKey, String currency,
  ) async {
    // Append row with formulas using USER_ENTERED
    await http.post(
      Uri.parse('$_baseUrl/$ssId/values/Prices!A:H:append?valueInputOption=USER_ENTERED'),
      headers: headers,
      body: jsonEncode({
        'values': [
          [
            ticker,
            market,
            gfKey,
            '=GOOGLEFINANCE("$gfKey","price")',
            '=GOOGLEFINANCE("$gfKey","name")',
            '=GOOGLEFINANCE("$gfKey","changepct")',
            '=GOOGLEFINANCE("$gfKey","closeyest")',
            currency,
          ]
        ]
      }),
    );
  }

  Future<void> _batchUpdate(String ssId, Map<String, String> headers, List<Map<String, dynamic>> data) async {
    await http.post(
      Uri.parse('$_baseUrl/$ssId/values:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'valueInputOption': 'RAW',
        'data': data,
      }),
    );
  }

  Map<String, dynamic> _valueRange(String range, List<List<String>> values) {
    return {'range': range, 'values': values};
  }

  List<List<dynamic>> _getRows(dynamic valueRange) {
    return (valueRange['values'] as List?)?.cast<List<dynamic>>() ?? [];
  }

  List<String> _padRow(List<dynamic> row, int length) {
    return List.generate(length, (i) => i < row.length ? row[i].toString() : '');
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```

- [ ] **Step 3: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/services/sheets_service.dart
git commit -m "feat: add Google Sheets API service (CRUD, batchGet, GOOGLEFINANCE formulas)"
```

---

### Task 7: Riverpod Providers

**Files:**
- Create: `portfolio-flutter/lib/providers/auth_provider.dart`
- Create: `portfolio-flutter/lib/providers/portfolio_provider.dart`
- Create: `portfolio-flutter/lib/providers/settings_provider.dart`

- [ ] **Step 1: auth_provider.dart**

`portfolio-flutter/lib/providers/auth_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<GoogleSignInAccount?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<GoogleSignInAccount?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _authService.signInSilently();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signIn();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}
```

- [ ] **Step 2: portfolio_provider.dart**

`portfolio-flutter/lib/providers/portfolio_provider.dart`:
```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../services/sheets_service.dart';
import '../engine/holdings_engine.dart';
import '../utils/constants.dart';
import 'auth_provider.dart';

final sheetsServiceProvider = Provider<SheetsService>((ref) {
  final authService = ref.read(authServiceProvider);
  return SheetsService(getAuthHeaders: authService.getAuthHeaders);
});

class PortfolioState {
  final List<Transaction> transactions;
  final List<Holding> holdings;
  final Map<String, StockQuote> quotes;
  final double exchangeRate;
  final List<OtherAsset> otherAssets;
  final AppSettings settings;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const PortfolioState({
    this.transactions = const [],
    this.holdings = const [],
    this.quotes = const {},
    this.exchangeRate = 1450,
    this.otherAssets = const [],
    this.settings = const AppSettings(),
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  PortfolioState copyWith({
    List<Transaction>? transactions,
    List<Holding>? holdings,
    Map<String, StockQuote>? quotes,
    double? exchangeRate,
    List<OtherAsset>? otherAssets,
    AppSettings? settings,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return PortfolioState(
      transactions: transactions ?? this.transactions,
      holdings: holdings ?? this.holdings,
      quotes: quotes ?? this.quotes,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      otherAssets: otherAssets ?? this.otherAssets,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

final portfolioProvider = StateNotifierProvider<PortfolioNotifier, PortfolioState>((ref) {
  return PortfolioNotifier(ref.read(sheetsServiceProvider));
});

class PortfolioNotifier extends StateNotifier<PortfolioState> {
  final SheetsService _sheets;
  Timer? _refreshTimer;

  PortfolioNotifier(this._sheets) : super(const PortfolioState());

  /// 스프레드시트 ID 설정 + 데이터 로드
  Future<void> connect(String spreadsheetId) async {
    _sheets.setSpreadsheetId(spreadsheetId);
    await loadAll();
  }

  /// 새 스프레드시트 생성 + 연결
  Future<String> createAndConnect() async {
    state = state.copyWith(isLoading: true);
    try {
      final id = await _sheets.createSpreadsheet();
      await connect(id);
      return id;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// 전체 데이터 로드 (초기 로드)
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _sheets.loadAll();
      final holdings = replayTransactions(data.transactions);
      final quotesMap = {for (final q in data.quotes) q.ticker: q};

      state = state.copyWith(
        transactions: data.transactions,
        holdings: holdings,
        quotes: quotesMap,
        exchangeRate: data.exchangeRate,
        otherAssets: data.otherAssets,
        settings: data.settings,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      _startRefreshTimer(data.settings.refreshInterval);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 시세만 갱신
  Future<void> refreshPrices() async {
    try {
      final data = await _sheets.loadPrices();
      final quotesMap = {for (final q in data.quotes) q.ticker: q};
      state = state.copyWith(
        quotes: quotesMap,
        exchangeRate: data.exchangeRate,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 거래 추가
  Future<void> addTransaction(Transaction tx) async {
    await _sheets.addTransaction(tx);
    // 로컬 상태 즉시 갱신
    final newTxs = [...state.transactions, tx];
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);

    // 새 종목이면 Prices 시트에 수식 추가
    final existingTickers = state.quotes.keys.toSet();
    if (!existingTickers.contains(tx.ticker)) {
      await _sheets.addPriceRow(
        tx.ticker,
        tx.market.toSheetValue(),
        tx.currency == Currency.krw ? 'KRW' : 'USD',
      );
    }
  }

  /// 거래 수정
  Future<void> updateTransaction(Transaction tx, int index) async {
    await _sheets.updateTransaction(tx, index);
    final newTxs = List<Transaction>.from(state.transactions);
    newTxs[index] = tx;
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);
  }

  /// 거래 삭제
  Future<void> deleteTransaction(int index) async {
    await _sheets.deleteTransaction(index);
    final newTxs = List<Transaction>.from(state.transactions)..removeAt(index);
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);
  }

  void _startRefreshTimer(int intervalSeconds) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => refreshPrices(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// localStorage에서 스프레드시트 ID 관리
final spreadsheetIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('spreadsheet_id');
});

Future<void> saveSpreadsheetId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('spreadsheet_id', id);
}
```

- [ ] **Step 3: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```

- [ ] **Step 4: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/providers/
git commit -m "feat: add Riverpod providers (auth, portfolio, settings)"
```

---

### Task 8: 로그인 화면

**Files:**
- Create: `portfolio-flutter/lib/screens/login_screen.dart`
- Modify: `portfolio-flutter/lib/main.dart`
- Create: `portfolio-flutter/lib/app.dart`

- [ ] **Step 1: app.dart 작성 (라우팅 + 테마)**

`portfolio-flutter/lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/portfolio_provider.dart';
import 'screens/login_screen.dart';
import 'screens/sheet_connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'utils/constants.dart';

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Portfolio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6E6E)),
        useMaterial3: true,
      ),
      home: authState.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
        data: (user) {
          if (user == null) return const LoginScreen();
          return const SheetConnectGate();
        },
      ),
    );
  }
}

/// 스프레드시트 연결 확인 게이트
class SheetConnectGate extends ConsumerWidget {
  const SheetConnectGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssId = ref.watch(spreadsheetIdProvider);
    return ssId.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SheetConnectScreen(),
      data: (id) {
        if (id == null || id.isEmpty) return const SheetConnectScreen();
        return const MainApp();
      },
    );
  }
}

/// 메인 앱 (탭 네비게이션) — Phase 1에서는 대시보드와 포트폴리오만
class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final ssId = await ref.read(spreadsheetIdProvider.future);
    if (ssId != null) {
      await ref.read(portfolioProvider.notifier).connect(ssId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const Placeholder(), // Portfolio — Task 11
      const Placeholder(), // History — Phase 2
      const Placeholder(), // Other Assets — Phase 2
      const Placeholder(), // Settings — Phase 2
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '대시보드'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '포트폴리오'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '거래내역'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: '기타자산'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: login_screen.dart 작성**

`portfolio-flutter/lib/screens/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 80, color: Color(0xFF0D6E6E)),
            const SizedBox(height: 16),
            Text('Portfolio', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('자산 관리 앱', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => ref.read(authStateProvider.notifier).signIn(),
              icon: const Icon(Icons.login),
              label: const Text('Google로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: sheet_connect_screen.dart 작성**

`portfolio-flutter/lib/screens/sheet_connect_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';

class SheetConnectScreen extends ConsumerStatefulWidget {
  const SheetConnectScreen({super.key});

  @override
  ConsumerState<SheetConnectScreen> createState() => _SheetConnectScreenState();
}

class _SheetConnectScreenState extends ConsumerState<SheetConnectScreen> {
  bool _isCreating = false;
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _createNew() async {
    setState(() => _isCreating = true);
    try {
      final id = await ref.read(portfolioProvider.notifier).createAndConnect();
      await saveSpreadsheetId(id);
      if (mounted) {
        // SheetConnectGate가 자동으로 MainApp으로 전환
        ref.invalidate(spreadsheetIdProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _connectExisting() async {
    // URL에서 spreadsheet ID 추출
    final url = _urlController.text.trim();
    final id = _extractSpreadsheetId(url);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 Google Sheets URL을 입력해주세요')),
      );
      return;
    }

    try {
      await saveSpreadsheetId(id);
      await ref.read(portfolioProvider.notifier).connect(id);
      ref.invalidate(spreadsheetIdProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    }
  }

  String? _extractSpreadsheetId(String input) {
    // URL: https://docs.google.com/spreadsheets/d/{ID}/edit...
    final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(input);
    if (match != null) return match.group(1);
    // 직접 ID 입력
    if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(input)) return input;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.table_chart, size: 64, color: Color(0xFF0D6E6E)),
                const SizedBox(height: 16),
                Text('스프레드시트 연결', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createNew,
                  icon: _isCreating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add),
                  label: const Text('새 스프레드시트 생성'),
                ),
                const SizedBox(height: 24),
                const Text('또는'),
                const SizedBox(height: 24),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '스프레드시트 URL',
                    hintText: 'https://docs.google.com/spreadsheets/d/...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _connectExisting,
                  icon: const Icon(Icons.link),
                  label: const Text('기존 스프레드시트 연결'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

> Note: Google Picker API 통합은 Phase 2에서 추가. Phase 1에서는 URL 직접 입력 방식으로 동작.

- [ ] **Step 4: main.dart 업데이트**

`portfolio-flutter/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: PortfolioApp()));
}
```

- [ ] **Step 5: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze && flutter build web
```

- [ ] **Step 6: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/main.dart portfolio-flutter/lib/app.dart portfolio-flutter/lib/screens/login_screen.dart portfolio-flutter/lib/screens/sheet_connect_screen.dart
git commit -m "feat: add login, sheet connect screens with auth flow"
```

---

### Task 9: 대시보드 화면

**Files:**
- Create: `portfolio-flutter/lib/screens/dashboard_screen.dart`
- Create: `portfolio-flutter/lib/widgets/total_asset_card.dart`
- Create: `portfolio-flutter/lib/widgets/account_card.dart`

**Reference:** `portfolio-app/app/(tabs)/index.tsx`

- [ ] **Step 1: total_asset_card.dart 작성**

`portfolio-flutter/lib/widgets/total_asset_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class TotalAssetCard extends StatelessWidget {
  final double totalValueKRW;
  final double totalValueUSD;
  final double totalCostKRW;
  final double totalProfitKRW;
  final double totalProfitPercentKRW;
  final double dailyChangeKRW;
  final double dailyChangePct;

  const TotalAssetCard({
    super.key,
    required this.totalValueKRW,
    required this.totalValueUSD,
    required this.totalCostKRW,
    required this.totalProfitKRW,
    required this.totalProfitPercentKRW,
    required this.dailyChangeKRW,
    required this.dailyChangePct,
  });

  @override
  Widget build(BuildContext context) {
    final profitColor = totalProfitKRW >= 0 ? positiveColor : negativeColor;
    final dailyColor = dailyChangeKRW >= 0 ? positiveColor : negativeColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('총 자산', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(formatKRW(totalValueKRW), style: Theme.of(context).textTheme.headlineMedium),
            Text(formatUSD(totalValueUSD), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label(context, '매입가', formatKRW(totalCostKRW)),
                _label(context, '수익', formatKRW(totalProfitKRW), color: profitColor),
                _label(context, '수익률', formatPercent(totalProfitPercentKRW), color: profitColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('일간 ', style: Theme.of(context).textTheme.bodySmall),
                Text(formatKRW(dailyChangeKRW), style: TextStyle(color: dailyColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(formatPercent(dailyChangePct), style: TextStyle(color: dailyColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
```

- [ ] **Step 2: account_card.dart 작성**

`portfolio-flutter/lib/widgets/account_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class AccountCard extends StatelessWidget {
  final String account;
  final Color color;
  final double valueKRW;
  final double profitKRW;
  final double profitPercentKRW;

  const AccountCard({
    super.key,
    required this.account,
    required this.color,
    required this.valueKRW,
    required this.profitKRW,
    required this.profitPercentKRW,
  });

  @override
  Widget build(BuildContext context) {
    final profitColor = profitKRW >= 0 ? positiveColor : negativeColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(account, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatKRW(valueKRW), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(formatKRW(profitKRW), style: TextStyle(color: profitColor, fontSize: 13)),
                const SizedBox(width: 8),
                Text(formatPercent(profitPercentKRW), style: TextStyle(color: profitColor, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: dashboard_screen.dart 작성**

`portfolio-flutter/lib/screens/dashboard_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../engine/calculations.dart';
import '../widgets/total_asset_card.dart';
import '../widgets/account_card.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);

    if (portfolio.isLoading && portfolio.holdings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 총자산 계산
    double totalValueKRW = 0;
    double totalCostKRW = 0;
    double totalDailyChange = 0;

    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;

      totalValueKRW += calcTotalValueKRW(h, price, portfolio.exchangeRate);
      totalCostKRW += calcCostKRW(h);
      totalDailyChange += calcDailyChangeKRW(h, price, closeYest, portfolio.exchangeRate);
    }

    // 기타 자산 합산
    for (final oa in portfolio.otherAssets) {
      final v = oa.currency == Currency.krw
          ? oa.value
          : oa.value * portfolio.exchangeRate;
      totalValueKRW += v;
      totalCostKRW += v; // 기타 자산은 cost = value
    }

    final totalProfitKRW = totalValueKRW - totalCostKRW;
    final totalProfitPct = totalCostKRW > 0 ? (totalProfitKRW / totalCostKRW) * 100 : 0.0;
    final dailyChangePct = (totalValueKRW - totalDailyChange) > 0
        ? (totalDailyChange / (totalValueKRW - totalDailyChange)) * 100
        : 0.0;
    final totalValueUSD = portfolio.exchangeRate > 0 ? totalValueKRW / portfolio.exchangeRate : 0.0;

    // 계좌별 집계
    final accountMap = <String, ({double value, double cost})>{};
    for (final h in portfolio.holdings) {
      final quote = portfolio.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final entry = accountMap[h.account] ?? (value: 0.0, cost: 0.0);
      accountMap[h.account] = (
        value: entry.value + calcTotalValueKRW(h, price, portfolio.exchangeRate),
        cost: entry.cost + calcCostKRW(h),
      );
    }
    for (final oa in portfolio.otherAssets) {
      final v = oa.currency.index == 1 ? oa.value : oa.value * portfolio.exchangeRate;
      final entry = accountMap[oa.account] ?? (value: 0.0, cost: 0.0);
      accountMap[oa.account] = (value: entry.value + v, cost: entry.cost + v);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TotalAssetCard(
            totalValueKRW: totalValueKRW,
            totalValueUSD: totalValueUSD,
            totalCostKRW: totalCostKRW,
            totalProfitKRW: totalProfitKRW,
            totalProfitPercentKRW: totalProfitPct,
            dailyChangeKRW: totalDailyChange,
            dailyChangePct: dailyChangePct,
          ),
          const SizedBox(height: 8),
          // 메타: 환율 + 마지막 업데이트
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 USD = ${formatKRW(portfolio.exchangeRate)}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (portfolio.lastUpdated != null)
                    Text(formatRelativeTime(portfolio.lastUpdated!.toIso8601String()),
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('BY ACCOUNT', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...accountMap.entries.indexed.map((e) {
            final (index, entry) = e;
            final profit = entry.value.value - entry.value.cost;
            final pct = entry.value.cost > 0 ? (profit / entry.value.cost) * 100 : 0.0;
            return AccountCard(
              account: entry.key,
              color: getAccountColor(index),
              valueKRW: entry.value.value,
              profitKRW: profit,
              profitPercentKRW: pct,
            );
          }),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze && flutter build web
```

- [ ] **Step 5: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/screens/dashboard_screen.dart portfolio-flutter/lib/widgets/total_asset_card.dart portfolio-flutter/lib/widgets/account_card.dart
git commit -m "feat: add dashboard screen with total asset and account cards"
```

---

### Task 10: 포트폴리오 화면

**Files:**
- Create: `portfolio-flutter/lib/screens/portfolio_screen.dart`
- Create: `portfolio-flutter/lib/widgets/holding_card.dart`
- Create: `portfolio-flutter/lib/widgets/filter_tabs.dart`

**Reference:** `portfolio-app/app/(tabs)/portfolio.tsx`

- [ ] **Step 1: filter_tabs.dart 작성**

`portfolio-flutter/lib/widgets/filter_tabs.dart`:
```dart
import 'package:flutter/material.dart';

class FilterTabs extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 2: holding_card.dart 작성**

`portfolio-flutter/lib/widgets/holding_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../engine/calculations.dart';
import '../utils/format.dart';
import '../utils/constants.dart';

class HoldingCard extends StatelessWidget {
  final Holding holding;
  final StockQuote? quote;
  final double exchangeRate;

  const HoldingCard({
    super.key,
    required this.holding,
    required this.quote,
    required this.exchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    final price = quote?.price ?? 0;
    final profitKRW = calcProfitKRW(holding, price, exchangeRate);
    final profitPctKRW = calcProfitPercentKRW(holding, price, exchangeRate);
    final valueKRW = calcTotalValueKRW(holding, price, exchangeRate);
    final profitColor = profitKRW >= 0 ? positiveColor : negativeColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote?.name ?? holding.ticker,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(holding.ticker,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(holding.currency == Currency.usd ? formatUSD(price) : formatKRW(price),
                        style: Theme.of(context).textTheme.titleSmall),
                    if (quote != null)
                      Text(formatPercent(quote!.changePct),
                          style: TextStyle(
                            color: quote!.changePct >= 0 ? positiveColor : negativeColor,
                            fontSize: 12,
                          )),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _info(context, '수량', formatShares(holding.shares)),
                _info(context, '평가금액', formatKRW(valueKRW)),
                _info(context, '수익', formatKRW(profitKRW), color: profitColor),
                _info(context, '수익률', formatPercent(profitPctKRW), color: profitColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _info(context, '평단가',
                    holding.currency == Currency.usd ? formatUSD(holding.avgCost) : formatKRW(holding.avgCost)),
                if (holding.currency == Currency.usd) ...[
                  const SizedBox(width: 16),
                  _info(context, '매입환율', formatKRW(holding.avgExchangeRate)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
```

- [ ] **Step 3: portfolio_screen.dart 작성**

`portfolio-flutter/lib/screens/portfolio_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import '../models/transaction.dart';
import '../widgets/holding_card.dart';
import '../widgets/filter_tabs.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  String _accountFilter = '전체';
  String _marketFilter = '전체';

  @override
  Widget build(BuildContext context) {
    final portfolio = ref.watch(portfolioProvider);
    final accounts = ['전체', ...portfolio.settings.accounts];

    var holdings = portfolio.holdings;

    // 필터 적용
    if (_accountFilter != '전체') {
      holdings = holdings.where((h) => h.account == _accountFilter).toList();
    }
    if (_marketFilter != '전체') {
      final marketMap = {'미국': Market.us, '한국 (KRX)': Market.krx, '한국 (KOSDAQ)': Market.kosdaq};
      final targetMarkets = _marketFilter == '한국'
          ? [Market.krx, Market.kosdaq]
          : [marketMap[_marketFilter] ?? Market.us];
      holdings = holdings.where((h) => targetMarkets.contains(h.market)).toList();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilterTabs(
            options: accounts,
            selected: _accountFilter,
            onChanged: (v) => setState(() => _accountFilter = v),
          ),
          const SizedBox(height: 8),
          FilterTabs(
            options: const ['전체', '미국', '한국', '기타'],
            selected: _marketFilter,
            onChanged: (v) => setState(() => _marketFilter = v),
          ),
          const SizedBox(height: 16),
          if (holdings.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('보유 종목이 없습니다'),
            ))
          else
            ...holdings.map((h) => HoldingCard(
              holding: h,
              quote: portfolio.quotes[h.ticker],
              exchangeRate: portfolio.exchangeRate,
            )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: app.dart에서 Portfolio 화면 연결**

`portfolio-flutter/lib/app.dart`의 `MainApp._currentIndex`에서 `Placeholder()`를 `PortfolioScreen()`으로 교체:

```dart
// screens 배열에서
const PortfolioScreen(), // index 1 — Portfolio
```

import 추가:
```dart
import 'screens/portfolio_screen.dart';
```

- [ ] **Step 5: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze && flutter build web
```

- [ ] **Step 6: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/screens/portfolio_screen.dart portfolio-flutter/lib/widgets/ portfolio-flutter/lib/app.dart
git commit -m "feat: add portfolio screen with holding cards and filters"
```

---

### Task 11: CORS 프록시 검색 엔드포인트 추가

**Files:**
- Modify: `portfolio-cors-proxy/src/index.ts`

**Reference:** 스펙 섹션 4, 11

- [ ] **Step 1: index.ts에 /search 엔드포인트 추가**

`portfolio-cors-proxy/src/index.ts` 전체 교체:

```typescript
interface Env {
  ALLOWED_ORIGINS: string;
}

const YAHOO_CHART_BASE = 'https://query1.finance.yahoo.com/v8/finance/chart';
const YAHOO_SEARCH_BASE = 'https://query2.finance.yahoo.com/v1/finance/search';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') ?? '';
    const allowed = env.ALLOWED_ORIGINS.split(',');
    const allowedOrigin = allowed.includes(origin) ? origin : allowed[0];

    const corsHeaders = {
      'Access-Control-Allow-Origin': allowedOrigin,
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      // /search 엔드포인트: 종목 검색
      if (url.pathname === '/search') {
        const q = url.searchParams.get('q');
        if (!q) {
          return jsonResponse({ error: 'q parameter required' }, 400, corsHeaders);
        }
        const yahooUrl = `${YAHOO_SEARCH_BASE}?q=${encodeURIComponent(q)}&quotesCount=10&newsCount=0`;
        const yahooRes = await fetch(yahooUrl, {
          headers: { 'User-Agent': 'Mozilla/5.0' },
        });
        const data = await yahooRes.text();
        return new Response(data, {
          status: yahooRes.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=300' },
        });
      }

      // 기존: /quote (하위 호환)
      const symbol = url.searchParams.get('symbol');
      const range = url.searchParams.get('range') || '1d';
      const interval = url.searchParams.get('interval') || '1d';

      if (!symbol) {
        return jsonResponse({ error: 'symbol parameter required' }, 400, corsHeaders);
      }

      const yahooUrl = `${YAHOO_CHART_BASE}/${encodeURIComponent(symbol)}?range=${range}&interval=${interval}`;
      const yahooRes = await fetch(yahooUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      const data = await yahooRes.text();
      return new Response(data, {
        status: yahooRes.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60' },
      });
    } catch (err: any) {
      return jsonResponse({ error: err.message }, 502, corsHeaders);
    }
  },
};

function jsonResponse(body: object, status: number, headers: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}
```

- [ ] **Step 2: ALLOWED_ORIGINS에 새 도메인 추가 필요 여부 확인**

Flutter 앱의 GitHub Pages URL이 기존과 다르면 `wrangler.toml`의 `ALLOWED_ORIGINS`에 추가해야 함. 동일 도메인이면 변경 불필요.

- [ ] **Step 3: 로컬 테스트**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-cors-proxy"
npx wrangler dev --local
```

별도 터미널에서:
```bash
curl "http://localhost:8787/search?q=tesla"
```
Expected: Yahoo Finance 검색 결과 JSON 반환

- [ ] **Step 4: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-cors-proxy/src/index.ts
git commit -m "feat: add /search endpoint to CORS proxy for stock search"
```

---

### Task 12: 테스트 보강

**Files:**
- Modify: `portfolio-flutter/test/engine/calculations_test.dart`
- Modify: `portfolio-flutter/test/engine/holdings_engine_test.dart`

- [ ] **Step 1: calculations 테스트 추가**

`portfolio-flutter/test/engine/calculations_test.dart`에 추가:

```dart
  group('calcProfitPercentUSD', () {
    test('positive', () {
      expect(calcProfitPercentUSD(usdHolding, 350), closeTo(16.67, 0.01));
    });
    test('zero avgCost returns 0', () {
      final zeroCost = Holding(
        account: '본석', ticker: 'X', market: Market.us,
        currency: Currency.usd, shares: 10, avgCost: 0, avgExchangeRate: 0,
      );
      expect(calcProfitPercentUSD(zeroCost, 100), 0);
    });
  });

  group('calcProfitPercentKRW', () {
    test('positive', () {
      // cost = 300*10*1400 = 4,200,000, value = 350*10*1500 = 5,250,000
      // (5250000-4200000)/4200000*100 = 25.0
      expect(calcProfitPercentKRW(usdHolding, 350, 1500), 25.0);
    });
    test('zero cost returns 0', () {
      final zeroCost = Holding(
        account: '본석', ticker: 'X', market: Market.us,
        currency: Currency.usd, shares: 0, avgCost: 0, avgExchangeRate: 0,
      );
      expect(calcProfitPercentKRW(zeroCost, 100, 1500), 0);
    });
  });

  group('calcRealizedPL', () {
    test('profit on sell', () {
      final result = calcRealizedPL(5, 400, 1500, 300, 1400);
      expect(result.usd, 500); // (400-300)*5
      expect(result.krw, 900000); // 400*5*1500 - 300*5*1400
    });
  });
```

- [ ] **Step 2: holdings_engine 테스트 추가**

`portfolio-flutter/test/engine/holdings_engine_test.dart`에 추가:

```dart
    test('opening_balance works like buy', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.openingBalance, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 10);
    });

    test('oversell removes holding', () {
      final txs = [
        Transaction(
          id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 300, currency: Currency.usd,
          exchangeRate: 1400,
        ),
        Transaction(
          id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd,
          exchangeRate: 1500,
        ),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 0);
    });
```

- [ ] **Step 3: 테스트 실행**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter test
```
Expected: All tests pass

- [ ] **Step 4: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/test/
git commit -m "test: add missing calculations and edge case tests"
```

---

### Task 13: 거래 추가 모달

**Files:**
- Create: `portfolio-flutter/lib/widgets/add_transaction_modal.dart`
- Modify: `portfolio-flutter/lib/screens/portfolio_screen.dart` (FAB 추가)

**Reference:** `portfolio-app/src/components/AddTransactionModal.tsx`

- [ ] **Step 1: add_transaction_modal.dart 작성**

`portfolio-flutter/lib/widgets/add_transaction_modal.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  const AddTransactionModal({super.key});

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _nameController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _rateController = TextEditingController();
  final _memoController = TextEditingController();

  TransactionType _type = TransactionType.buy;
  Market _market = Market.us;
  Currency _currency = Currency.usd;
  String _account = '';
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final accounts = ref.read(portfolioProvider).settings.accounts;
    if (accounts.isNotEmpty) _account = accounts.first;
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _rateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_account.isEmpty) return;

    setState(() => _isSaving = true);

    final tx = Transaction(
      id: const Uuid().v4(),
      date: _date.toIso8601String().substring(0, 10),
      account: _account,
      type: _type,
      ticker: _tickerController.text.trim().toUpperCase(),
      market: _market,
      name: _nameController.text.trim(),
      shares: double.tryParse(_sharesController.text) ?? 0,
      price: double.tryParse(_priceController.text) ?? 0,
      currency: _currency,
      exchangeRate: double.tryParse(_rateController.text) ?? 0,
      memo: _memoController.text.trim(),
    );

    try {
      await ref.read(portfolioProvider.notifier).addTransaction(tx);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(portfolioProvider).settings.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 추가'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 거래 유형
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.buy, label: Text('매수')),
                ButtonSegment(value: TransactionType.sell, label: Text('매도')),
                ButtonSegment(value: TransactionType.openingBalance, label: Text('기초잔고')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),

            // 계좌
            if (accounts.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _account.isNotEmpty ? _account : null,
                decoration: const InputDecoration(labelText: '계좌', border: OutlineInputBorder()),
                items: accounts.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setState(() => _account = v ?? ''),
              ),
            const SizedBox(height: 16),

            // 시장
            SegmentedButton<Market>(
              segments: const [
                ButtonSegment(value: Market.us, label: Text('US')),
                ButtonSegment(value: Market.krx, label: Text('KRX')),
                ButtonSegment(value: Market.kosdaq, label: Text('KOSDAQ')),
              ],
              selected: {_market},
              onSelectionChanged: (v) {
                setState(() {
                  _market = v.first;
                  _currency = v.first == Market.us ? Currency.usd : Currency.krw;
                });
              },
            ),
            const SizedBox(height: 16),

            // 종목코드 + 종목명
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tickerController,
                    decoration: const InputDecoration(labelText: '종목코드', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '종목명', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 수량 + 가격
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sharesController,
                    decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: '단가 (${_currency == Currency.usd ? "USD" : "KRW"})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? '필수' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 환율 (USD만)
            if (_currency == Currency.usd)
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(labelText: '매입 환율 (USD/KRW)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            if (_currency == Currency.usd) const SizedBox(height: 16),

            // 날짜
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('날짜'),
              subtitle: Text(_date.toIso8601String().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),

            // 메모
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: '메모', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 포트폴리오 화면에 FAB 추가**

`portfolio-flutter/lib/screens/portfolio_screen.dart`에서 `Scaffold` wrapping 추가:

portfolio_screen.dart의 `build` 메서드 리턴을 감싸서:
```dart
return Scaffold(
  body: RefreshIndicator(
    // ... 기존 코드
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddTransactionModal()),
      );
    },
    child: const Icon(Icons.add),
  ),
);
```

import 추가:
```dart
import '../widgets/add_transaction_modal.dart';
```

- [ ] **Step 3: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze && flutter build web
```

- [ ] **Step 4: 커밋**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git add portfolio-flutter/lib/widgets/add_transaction_modal.dart portfolio-flutter/lib/screens/portfolio_screen.dart
git commit -m "feat: add transaction creation modal with form validation"
```

---

### Task 14: 전체 빌드 검증 및 Phase 1 완료

**Files:** 없음 (검증만)

- [ ] **Step 1: 전체 테스트 실행**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter test
```
Expected: All tests pass

- [ ] **Step 2: 빌드 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter build web
```
Expected: 빌드 성공

- [ ] **Step 3: analyze 확인**

```bash
cd "/Users/venaki/Documents/Project/Financial App/portfolio-flutter"
flutter analyze
```
Expected: No issues found

- [ ] **Step 4: Phase 1 완료 태그**

```bash
cd "/Users/venaki/Documents/Project/Financial App"
git tag phase1-complete
```

---

## Phase 1 완료 후 다음 단계

Phase 2 플랜에서 다룰 항목:
- 거래 내역 화면 (편집/삭제 모달, 월별 그룹, 필터)
- 기타 자산 화면 (CRUD)
- 종목 검색 자동완성 위젯 (Yahoo Search API + CORS 프록시)
- 설정 화면 (계정 정보, 테마, 계좌 관리, CSV 내보내기, 시트 연결 변경)
- Google Picker API 통합
