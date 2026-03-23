# Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 거래내역/기타자산/설정 화면 + PC 반응형 레이아웃 + 종목 검색 자동완성을 구현한다.

**Architecture:** Flutter Web + Riverpod 상태관리 + Google Sheets API v4. 기존 Phase 1 (대시보드/포트폴리오) 위에 3개 화면, 6개 모달, PC 사이드바를 추가한다. rowIndex 기반 CRUD를 ID 기반으로 전환한다.

**Tech Stack:** Flutter 3.x, flutter_riverpod, google_sign_in, http, shared_preferences, intl, uuid

**Spec:** `docs/superpowers/specs/2026-03-23-phase2-design.md`

**pen 디자인:** `financial-app-design.pen` — 반드시 참조하여 UI 재현

**Working directory:** `portfolio-flutter/` (모든 상대 경로의 기준)

---

## File Structure

### 신규 파일

| 파일 | 역할 |
|------|------|
| `lib/widgets/responsive_shell.dart` | 768px breakpoint, 모바일 탭바/PC 사이드바 분기 |
| `lib/widgets/sidebar.dart` | PC 좌측 사이드바 (240px) |
| `lib/widgets/base_modal.dart` | 모달 공통 래퍼 (딤 배경 + 흰 카드) |
| `lib/widgets/segmented_filter.dart` | 세그먼트 컨트롤 (FilterTabs 리네이밍) |
| `lib/widgets/ticker_search.dart` | 종목 검색 자동완성 위젯 |
| `lib/widgets/transaction_card.dart` | 거래내역 카드 |
| `lib/widgets/asset_card.dart` | 기타자산 카드 |
| `lib/widgets/edit_transaction_modal.dart` | 거래 편집 모달 |
| `lib/widgets/transaction_delete_modal.dart` | 거래 삭제 확인 모달 |
| `lib/widgets/add_asset_modal.dart` | 자산 추가 모달 |
| `lib/widgets/edit_asset_modal.dart` | 자산 편집 모달 |
| `lib/widgets/account_delete_modal.dart` | 계정 삭제 모달 (차단/확인) |
| `lib/screens/history_screen.dart` | 거래내역 화면 |
| `lib/screens/assets_screen.dart` | 기타자산 화면 |
| `lib/screens/settings_screen.dart` | 설정 화면 |
| `test/id_based_crud_test.dart` | ID 기반 CRUD 테스트 |
| `test/filter_logic_test.dart` | 필터 로직 테스트 |
| `test/other_asset_crud_test.dart` | OtherAsset CRUD 테스트 |
| `test/settings_test.dart` | 설정 로직 테스트 |

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/app.dart` | ResponsiveShell 적용, 동적 accent color |
| `lib/services/sheets_service.dart` | ID 기반 CRUD, findRowById, OtherAsset CRUD |
| `lib/providers/portfolio_provider.dart` | ID 기반 시그니처, OtherAsset CRUD, updateSettings |
| `lib/widgets/add_transaction_modal.dart` | BaseModal 적용, TickerSearch 통합 |
| `lib/screens/portfolio_screen.dart` | +추가 버튼 제거, SegmentedFilter 적용 |
| `lib/widgets/filter_tabs.dart` | 삭제 (segmented_filter.dart로 대체) |

---

## Task 1: SegmentedFilter 리네이밍 + BaseModal

**Files:**
- Create: `lib/widgets/segmented_filter.dart`
- Create: `lib/widgets/base_modal.dart`
- Modify: `lib/screens/portfolio_screen.dart` (import 변경)
- Delete: `lib/widgets/filter_tabs.dart`

- [ ] **Step 1: FilterTabs → SegmentedFilter 리네이밍**

`lib/widgets/filter_tabs.dart`를 `lib/widgets/segmented_filter.dart`로 복사하고, 클래스명을 `SegmentedFilter`로 변경한다. 인터페이스는 동일하게 유지:

```dart
// lib/widgets/segmented_filter.dart
import 'package:flutter/material.dart';

class SegmentedFilter extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const SegmentedFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 기존 FilterTabs.build 코드 그대로 —
    // 배경 #F0F0F0, cornerRadius 8, padding 4, gap 4
    // 활성: 흰 배경 + shadow, 비활성: transparent
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0x10000000), blurRadius: 2, offset: const Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF888888),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 2: PortfolioScreen import 변경**

`portfolio_screen.dart`에서 `import '../widgets/filter_tabs.dart'`를 `import '../widgets/segmented_filter.dart'`로 변경하고, `FilterTabs` → `SegmentedFilter`로 사용처 변경.

- [ ] **Step 3: filter_tabs.dart 삭제**

- [ ] **Step 4: BaseModal 생성**

```dart
// lib/widgets/base_modal.dart
import 'package:flutter/material.dart';

class BaseModal extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxWidth;

  const BaseModal({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 560,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 24, color: Color(0xFF888888)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  /// BaseModal을 showDialog로 띄우는 헬퍼
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    double maxWidth = 560,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => BaseModal(title: title, child: child, maxWidth: maxWidth),
    );
  }
}
```

- [ ] **Step 5: 빌드 확인**

```bash
cd portfolio-flutter && flutter build web --no-tree-shake-icons 2>&1 | tail -5
```
Expected: 빌드 성공, 기존 테스트 통과

- [ ] **Step 6: 커밋**

```bash
git add lib/widgets/segmented_filter.dart lib/widgets/base_modal.dart lib/screens/portfolio_screen.dart
git rm lib/widgets/filter_tabs.dart
git commit -m "refactor: rename FilterTabs to SegmentedFilter, add BaseModal"
```

---

## Task 2: ID 기반 CRUD 전환

**Files:**
- Modify: `lib/services/sheets_service.dart`
- Modify: `lib/providers/portfolio_provider.dart`
- Create: `test/id_based_crud_test.dart`

- [ ] **Step 1: SheetsService에 findRowById 추가**

`sheets_service.dart`에 공통 헬퍼 추가:

```dart
/// ID로 시트에서 행 번호 찾기 (0-based, 헤더 제외)
/// 반환값은 시트 내 데이터 행 인덱스 (Sheets API에서 +2 해야 실제 행 번호)
Future<int> findRowById(String sheetName, String id) async {
  _ensureId();
  final headers = await _getAuthHeaders();
  final range = Uri.encodeComponent('$sheetName!A2:A');
  final res = await http.get(
    Uri.parse('$_baseUrl/$_spreadsheetId/values/$range'),
    headers: headers,
  );
  if (res.statusCode != 200) throw Exception('findRowById failed: ${res.body}');
  final data = jsonDecode(res.body);
  final rows = (data['values'] as List?)?.cast<List<dynamic>>() ?? [];
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].isNotEmpty && rows[i][0].toString() == id) return i;
  }
  throw Exception('Row with id "$id" not found in $sheetName');
}
```

- [ ] **Step 2: updateTransaction, deleteTransaction을 ID 기반으로 변경**

```dart
Future<void> updateTransaction(Transaction tx) async {
  final rowIndex = await findRowById('Transactions', tx.id);
  _ensureId();
  final headers = await _getAuthHeaders();
  headers['Content-Type'] = 'application/json';
  final range = 'Transactions!A${rowIndex + 2}:L${rowIndex + 2}';
  await http.put(
    Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent(range)}?valueInputOption=RAW'),
    headers: headers,
    body: jsonEncode({'values': [tx.toSheetRow()]}),
  );
}

Future<void> deleteTransaction(String id) async {
  final rowIndex = await findRowById('Transactions', id);
  _ensureId();
  final headers = await _getAuthHeaders();
  headers['Content-Type'] = 'application/json';
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
      'requests': [{
        'deleteDimension': {
          'range': {
            'sheetId': txSheetId,
            'dimension': 'ROWS',
            'startIndex': rowIndex + 1,
            'endIndex': rowIndex + 2,
          }
        }
      }]
    }),
  );
}
```

- [ ] **Step 3: OtherAsset CRUD 메서드 추가 (SheetsService)**

```dart
Future<void> addOtherAsset(OtherAsset asset) async {
  _ensureId();
  final headers = await _getAuthHeaders();
  headers['Content-Type'] = 'application/json';
  await http.post(
    Uri.parse('$_baseUrl/$_spreadsheetId/values/OtherAssets!A:H:append?valueInputOption=RAW'),
    headers: headers,
    body: jsonEncode({'values': [asset.toSheetRow()]}),
  );
}

Future<void> updateOtherAsset(OtherAsset asset) async {
  final rowIndex = await findRowById('OtherAssets', asset.id);
  _ensureId();
  final headers = await _getAuthHeaders();
  headers['Content-Type'] = 'application/json';
  final range = 'OtherAssets!A${rowIndex + 2}:H${rowIndex + 2}';
  await http.put(
    Uri.parse('$_baseUrl/$_spreadsheetId/values/${Uri.encodeComponent(range)}?valueInputOption=RAW'),
    headers: headers,
    body: jsonEncode({'values': [asset.toSheetRow()]}),
  );
}

Future<void> deleteOtherAsset(String id) async {
  final rowIndex = await findRowById('OtherAssets', id);
  _ensureId();
  final headers = await _getAuthHeaders();
  headers['Content-Type'] = 'application/json';
  final metaRes = await http.get(
    Uri.parse('$_baseUrl/$_spreadsheetId?fields=sheets.properties'),
    headers: headers,
  );
  final meta = jsonDecode(metaRes.body);
  final sheets = meta['sheets'] as List;
  final oaSheetId = (sheets.firstWhere(
    (s) => s['properties']['title'] == 'OtherAssets',
  ))['properties']['sheetId'];
  await http.post(
    Uri.parse('$_baseUrl/$_spreadsheetId:batchUpdate'),
    headers: headers,
    body: jsonEncode({
      'requests': [{
        'deleteDimension': {
          'range': {
            'sheetId': oaSheetId,
            'dimension': 'ROWS',
            'startIndex': rowIndex + 1,
            'endIndex': rowIndex + 2,
          }
        }
      }]
    }),
  );
}
```

- [ ] **Step 4: PortfolioNotifier 시그니처 변경**

```dart
Future<void> updateTransaction(Transaction tx) async {
  await _sheets.updateTransaction(tx);
  final newTxs = state.transactions.map((t) => t.id == tx.id ? tx : t).toList();
  final newHoldings = replayTransactions(newTxs);
  state = state.copyWith(transactions: newTxs, holdings: newHoldings);
}

Future<void> deleteTransaction(String id) async {
  await _sheets.deleteTransaction(id);
  final newTxs = state.transactions.where((t) => t.id != id).toList();
  final newHoldings = replayTransactions(newTxs);
  state = state.copyWith(transactions: newTxs, holdings: newHoldings);
}

Future<void> addOtherAsset(OtherAsset asset) async {
  await _sheets.addOtherAsset(asset);
  state = state.copyWith(otherAssets: [...state.otherAssets, asset]);
}

Future<void> updateOtherAsset(OtherAsset asset) async {
  await _sheets.updateOtherAsset(asset);
  final newOa = state.otherAssets.map((a) => a.id == asset.id ? asset : a).toList();
  state = state.copyWith(otherAssets: newOa);
}

Future<void> deleteOtherAsset(String id) async {
  await _sheets.deleteOtherAsset(id);
  final newOa = state.otherAssets.where((a) => a.id != id).toList();
  state = state.copyWith(otherAssets: newOa);
}

Future<void> updateSettings(AppSettings newSettings) async {
  final oldInterval = state.settings.refreshInterval;
  await _sheets.saveSettings(newSettings);
  state = state.copyWith(settings: newSettings);
  if (newSettings.refreshInterval != oldInterval) {
    _startRefreshTimer(newSettings.refreshInterval);
  }
}
```

- [ ] **Step 5: 기존 테스트 통과 확인**

```bash
cd portfolio-flutter && flutter test
```
Expected: 기존 22개 테스트 통과

- [ ] **Step 6: 커밋**

```bash
git add lib/services/sheets_service.dart lib/providers/portfolio_provider.dart
git commit -m "refactor: switch to ID-based CRUD, add OtherAsset CRUD and updateSettings"
```

---

## Task 3: Responsive Shell + Sidebar

**Files:**
- Create: `lib/widgets/responsive_shell.dart`
- Create: `lib/widgets/sidebar.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Sidebar 위젯 생성**

pen 디자인 `ANSBN/LXHNQ` 참조. 반드시 pen 파일의 스크린샷을 확인하여 디자인을 정확히 재현할 것.

```dart
// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const Sidebar({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    _SidebarItem(icon: Icons.home_outlined, label: '대시보드'),
    _SidebarItem(icon: Icons.bar_chart, label: '포트폴리오'),
    _SidebarItem(icon: Icons.schedule, label: '거래내역'),
    _SidebarItem(icon: Icons.account_balance_wallet_outlined, label: '기타 자산'),
    _SidebarItem(icon: Icons.settings_outlined, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(right: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            child: Row(
              children: [
                Icon(Icons.show_chart, size: 20, color: accentColor),
                const SizedBox(width: 10),
                Text('Portfolio', style: TextStyle(
                  fontFamily: 'Newsreader', fontSize: 22, fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A1A),
                )),
              ],
            ),
          ),
          // Nav items
          ...List.generate(_items.length, (i) {
            final isActive = i == currentIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_items[i].icon, size: 18,
                        color: isActive ? Colors.white : const Color(0xFF888888)),
                      const SizedBox(width: 10),
                      Text(_items[i].label, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white : const Color(0xFF666666),
                      )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem({required this.icon, required this.label});
}
```

- [ ] **Step 2: ResponsiveShell 위젯 생성**

```dart
// lib/widgets/responsive_shell.dart
import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'custom_tab_bar.dart';

class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  static const breakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= breakpoint;

    if (isDesktop) {
      return Row(
        children: [
          Sidebar(currentIndex: currentIndex, onTap: onTap),
          Expanded(child: child),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: child),
        CustomTabBar(currentIndex: currentIndex, onTap: onTap),
      ],
    );
  }
}
```

- [ ] **Step 3: app.dart에 ResponsiveShell 적용 + 동적 accent color**

`MainApp`의 `build` 메서드를 수정하고, `PortfolioApp`에서 accent color를 동적으로 반영:

```dart
// app.dart 수정 — PortfolioApp에서 accentColor watch
// import 추가: responsive_shell, history/assets/settings screens, utils/constants

class PortfolioApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final portfolio = ref.watch(portfolioProvider);
    final accentColor = hexToColor(portfolio.settings.accentColor);

    return MaterialApp(
      // ... 기존 동일
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,  // 동적 색상
          surface: const Color(0xFFFFFFFF),
        ),
        // ... 나머지 동일
      ),
      home: // ... 기존 동일
    );
  }
}

// MainApp.build 수정
class _MainAppState extends ConsumerState<MainApp> {
  int _currentIndex = 0;
  // ... initState 동일

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const PortfolioScreen(),
      const HistoryScreen(),      // Phase 2
      const AssetsScreen(),       // Phase 2
      const SettingsScreen(),     // Phase 2
    ];

    return Scaffold(
      body: ResponsiveShell(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        child: screens[_currentIndex],
      ),
    );
  }
}
```

**주의**: HistoryScreen, AssetsScreen, SettingsScreen은 아직 없으므로, 임시 Placeholder 위젯으로 대체하고 각 Task에서 교체한다.

- [ ] **Step 4: 빌드 확인 + 커밋**

```bash
cd portfolio-flutter && flutter build web --no-tree-shake-icons 2>&1 | tail -5
git add lib/widgets/responsive_shell.dart lib/widgets/sidebar.dart lib/app.dart
git commit -m "feat: add responsive shell with PC sidebar and dynamic accent color"
```

---

## Task 4: History Screen + Transaction Card

**Files:**
- Create: `lib/screens/history_screen.dart`
- Create: `lib/widgets/transaction_card.dart`
- Create: `test/filter_logic_test.dart`

- [ ] **Step 1: TransactionCard 위젯 생성**

pen 디자인 `RC3oh` 내 거래 카드 참조. 반드시 pen 스크린샷을 확인하여 레이아웃, 색상, 폰트를 정확히 재현할 것.

구조:
- 좌상: 타입 태그 (매수=teal, 매도=orange, 초기=gray, 조정=gray) + 종목명 + 시장태그(명의)
- 중간: 수량 · 단가 · 환율
- 하단: 날짜 (좌) + 총액 (우)
- GestureDetector로 탭 시 `onTap` 콜백 호출

```dart
// lib/widgets/transaction_card.dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/format.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  // ... pen 디자인 기반 구현 — 카드 스타일: borderRadius 12, border 1px #E5E5E5
  // 타입별 태그 색상, 수량·단가·환율 포맷, 총액 계산
}
```

- [ ] **Step 2: 필터 로직 테스트 작성**

```dart
// test/filter_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/transaction.dart';

// 테스트용 거래 데이터 생성 헬퍼
Transaction _tx({
  String account = '본석', Market market = Market.us,
  TransactionType type = TransactionType.buy, String ticker = 'TSLA',
}) => Transaction(
  id: '${ticker}_$account', date: '2026-03-15', account: account,
  type: type, ticker: ticker, market: market, name: ticker,
  shares: 10, price: 100, currency: Currency.usd, exchangeRate: 1350,
);

void main() {
  final transactions = [
    _tx(account: '본석', market: Market.us, type: TransactionType.buy),
    _tx(account: '연지', market: Market.krx, type: TransactionType.sell, ticker: '005930'),
    _tx(account: '본석', market: Market.kosdaq, type: TransactionType.buy, ticker: '000000'),
  ];

  List<Transaction> applyFilters(
    List<Transaction> txs,
    String marketFilter, String accountFilter, String typeFilter,
  ) {
    return txs.where((tx) {
      if (marketFilter == '미국' && tx.market != Market.us) return false;
      if (marketFilter == '한국' && tx.market != Market.krx && tx.market != Market.kosdaq) return false;
      if (accountFilter != '전체' && tx.account != accountFilter) return false;
      if (typeFilter == '매수' && tx.type == TransactionType.sell) return false;
      if (typeFilter == '매도' && tx.type != TransactionType.sell) return false;
      return true;
    }).toList();
  }

  test('전체 필터 - 모든 거래 반환', () {
    expect(applyFilters(transactions, '전체', '전체', '전체').length, 3);
  });

  test('미국 필터', () {
    final result = applyFilters(transactions, '미국', '전체', '전체');
    expect(result.length, 1);
    expect(result.first.market, Market.us);
  });

  test('한국 필터 - KRX + KOSDAQ', () {
    expect(applyFilters(transactions, '한국', '전체', '전체').length, 2);
  });

  test('명의 필터', () {
    expect(applyFilters(transactions, '전체', '연지', '전체').length, 1);
  });

  test('매수 필터', () {
    expect(applyFilters(transactions, '전체', '전체', '매수').length, 2);
  });

  test('복합 필터 - 한국 + 본석', () {
    expect(applyFilters(transactions, '한국', '본석', '전체').length, 1);
  });
}
```

- [ ] **Step 3: 테스트 실행**

```bash
cd portfolio-flutter && flutter test test/filter_logic_test.dart
```

- [ ] **Step 4: HistoryScreen 구현**

pen 디자인 `RC3oh` (모바일) / `ANSBN` (PC) 참조.

```dart
// lib/screens/history_screen.dart
// 구조:
// - Header: "거래내역" (Newsreader 40px) + [추가] 버튼
// - 3단 SegmentedFilter (자산클래스/명의/유형)
// - 월별 그룹 (YYYY년 MM월 라벨)
// - TransactionCard 리스트 (탭 → 편집 모달)
//
// ConsumerStatefulWidget으로 구현
// 필터 상태: _marketFilter, _accountFilter, _typeFilter
// 로딩/빈/에러 상태 처리
```

- [ ] **Step 5: app.dart의 Placeholder를 HistoryScreen으로 교체**

- [ ] **Step 6: 빌드 확인 + 테스트 + 커밋**

```bash
cd portfolio-flutter && flutter test && flutter build web --no-tree-shake-icons 2>&1 | tail -5
git add -A && git commit -m "feat: add History screen with 3-tier filters and TransactionCard"
```

---

## Task 5: Ticker Search Autocomplete

**Files:**
- Create: `lib/widgets/ticker_search.dart`

- [ ] **Step 1: TickerSearch 위젯 구현**

```dart
// lib/widgets/ticker_search.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class TickerSearchResult {
  final String ticker;
  final String name;
  final String exchange;
  const TickerSearchResult({required this.ticker, required this.name, required this.exchange});
}

class TickerSearch extends StatefulWidget {
  final String? initialValue;
  final bool readOnly;
  final ValueChanged<TickerSearchResult> onSelected;

  const TickerSearch({super.key, this.initialValue, this.readOnly = false, required this.onSelected});

  @override
  State<TickerSearch> createState() => _TickerSearchState();
}

class _TickerSearchState extends State<TickerSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<TickerSearchResult> _results = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() { _results = []; _showDropdown = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$corsProxyBase/search?q=$query'),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _results = data.map((item) => TickerSearchResult(
            ticker: item['symbol'] ?? '',
            name: item['name'] ?? '',
            exchange: item['exchange'] ?? '',
          )).take(5).toList();
          _showDropdown = _results.isNotEmpty;
        });
      }
    } catch (_) {
      // 네트워크 실패 시 드롭다운 숨김, 수동 입력 유지
      setState(() { _showDropdown = false; });
    }
  }

  // ... build: TextField + OverlayEntry 드롭다운
  // 드롭다운 항목: ticker / name / exchange 표시
  // 선택 시: _controller.text = ticker, onSelected 콜백, 드롭다운 닫기

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: 빌드 확인 + 커밋**

```bash
git add lib/widgets/ticker_search.dart
git commit -m "feat: add TickerSearch autocomplete widget"
```

---

## Task 6: Transaction Modals (추가 리팩토링 + 편집 + 삭제 확인)

**Files:**
- Modify: `lib/widgets/add_transaction_modal.dart` (BaseModal 적용, TickerSearch 통합)
- Create: `lib/widgets/edit_transaction_modal.dart`
- Create: `lib/widgets/transaction_delete_modal.dart`

- [ ] **Step 1: AddTransactionModal을 BaseModal + TickerSearch로 리팩토링**

pen 디자인 `JSPW8` 참조. 필드 순서 (pen 기준): 자산유형 → 명의 → 종목코드(자동완성) → 거래유형 → 수량 → 체결가 → 환율 → 날짜 → 메모. BaseModal 래퍼 사용.

- [ ] **Step 2: EditTransactionModal 생성**

pen 디자인 `AF52o` 참조. 기존 데이터 프리필 + 종목명 표시 + [삭제]/[저장] 버튼. 삭제 시 TransactionDeleteModal 표시.

```dart
// lib/widgets/edit_transaction_modal.dart
// BaseModal 래퍼 사용
// 종목코드+종목명 readonly 표시
// 삭제 버튼 → TransactionDeleteModal 표시
// 저장 버튼 → portfolioNotifier.updateTransaction(tx)
```

- [ ] **Step 3: TransactionDeleteModal 생성**

pen 디자인 `L7NXF` 참조.

```dart
// lib/widgets/transaction_delete_modal.dart
import 'package:flutter/material.dart';

class TransactionDeleteModal extends StatelessWidget {
  final VoidCallback onConfirm;

  const TransactionDeleteModal({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 320, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('거래 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('이 거래를 삭제하시겠습니까?', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('취소', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () { Navigator.of(context).pop(); onConfirm(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07B54), borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: HistoryScreen에 모달 연결**

TransactionCard onTap → EditTransactionModal, [추가] 버튼 → AddTransactionModal.

- [ ] **Step 5: 빌드 + 테스트 + 커밋**

```bash
cd portfolio-flutter && flutter test && flutter build web --no-tree-shake-icons 2>&1 | tail -5
git add -A && git commit -m "feat: add transaction modals (add/edit/delete) with BaseModal and TickerSearch"
```

---

## Task 7: Assets Screen + Asset Modals

**Files:**
- Create: `lib/screens/assets_screen.dart`
- Create: `lib/widgets/asset_card.dart`
- Create: `lib/widgets/add_asset_modal.dart`
- Create: `lib/widgets/edit_asset_modal.dart`
- Create: `test/other_asset_crud_test.dart`

- [ ] **Step 1: OtherAsset 합계 계산 테스트**

```dart
// test/other_asset_crud_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  final assets = [
    OtherAsset(id: '1', account: '본석', name: '예금', category: AssetCategory.savings,
      value: 50000000, currency: Currency.krw, date: '2026-01-01'),
    OtherAsset(id: '2', account: '연지', name: '채권', category: AssetCategory.bond,
      value: 20000000, currency: Currency.krw, date: '2026-01-01'),
    OtherAsset(id: '3', account: '본석', name: '대출', category: AssetCategory.loan,
      value: -15000000, currency: Currency.krw, date: '2026-01-01'),
  ];

  double calcTotal(List<OtherAsset> list, String accountFilter) {
    return list
      .where((a) => accountFilter == '전체' || a.account == accountFilter)
      .fold(0.0, (sum, a) => sum + a.value);
  }

  test('전체 합계 = 55,000,000', () {
    expect(calcTotal(assets, '전체'), 55000000);
  });

  test('본석 합계 = 35,000,000', () {
    expect(calcTotal(assets, '본석'), 35000000);
  });

  test('연지 합계 = 20,000,000', () {
    expect(calcTotal(assets, '연지'), 20000000);
  });
}
```

- [ ] **Step 2: 테스트 실행**

```bash
cd portfolio-flutter && flutter test test/other_asset_crud_test.dart
```

- [ ] **Step 3: AssetCard 위젯 생성**

pen 디자인 `Gw4xU` 내 카드 참조. 구조: 자산명 (볼드) / 태그(명의·카테고리·통화) / 금액 (대출은 빨간색 음수).

- [ ] **Step 4: AssetsScreen 구현**

pen 디자인 `Gw4xU` (모바일) / `0Ywgs` (PC) 참조.
- Header: "기타 자산" (Newsreader 40px) + [추가] 버튼
- SegmentedFilter: 전체 / {accounts}
- 합계 행
- AssetCard 리스트
- 로딩/빈/에러 상태 처리

- [ ] **Step 5: AddAssetModal + EditAssetModal 생성**

pen 디자인 `oe2p6` (추가), `RqIs8` (편집) 참조. BaseModal 래퍼 사용.
- 추가: 명의 chip → 자산유형 chip (예금/채권/대출/기타) → 자산명 → 금액 → 통화 → 메모 → [추가]
- 편집: 프리필 + [삭제]/[저장]

- [ ] **Step 6: app.dart의 Placeholder를 AssetsScreen으로 교체**

- [ ] **Step 7: 빌드 + 테스트 + 커밋**

```bash
cd portfolio-flutter && flutter test && flutter build web --no-tree-shake-icons 2>&1 | tail -5
git add -A && git commit -m "feat: add Assets screen with CRUD modals and AssetCard"
```

---

## Task 8: Settings Screen

**Files:**
- Create: `lib/screens/settings_screen.dart`
- Create: `lib/widgets/account_delete_modal.dart`
- Create: `test/settings_test.dart`

- [ ] **Step 1: 설정 로직 테스트**

```dart
// test/settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  test('명의 삭제 차단 - 거래가 있는 명의', () {
    final transactions = [
      Transaction(id: '1', date: '2026-03-15', account: '본석',
        type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
        name: 'Tesla', shares: 10, price: 100, currency: Currency.usd, exchangeRate: 1350),
    ];
    final canDelete = !transactions.any((t) => t.account == '본석');
    expect(canDelete, false);
  });

  test('명의 삭제 허용 - 거래가 없는 명의', () {
    final transactions = [
      Transaction(id: '1', date: '2026-03-15', account: '본석',
        type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
        name: 'Tesla', shares: 10, price: 100, currency: Currency.usd, exchangeRate: 1350),
    ];
    final canDelete = !transactions.any((t) => t.account == '나은');
    expect(canDelete, true);
  });

  test('refreshInterval 분→초 변환', () {
    const minutes = 15;
    expect(minutes * 60, 900);
  });

  test('accentColor hex 파싱', () {
    const settings = AppSettings(accentColor: '#2563EB');
    expect(settings.accentColor, '#2563EB');
  });
}
```

- [ ] **Step 2: 테스트 실행**

```bash
cd portfolio-flutter && flutter test test/settings_test.dart
```

- [ ] **Step 3: AccountDeleteModal 생성**

pen 디자인 `dI6Ak` (차단), `pCN2B` (확인) 참조.

```dart
// lib/widgets/account_delete_modal.dart
// 차단 모달: "N건의 거래내역이 있어 삭제할 수 없습니다" + [확인] 버튼
// 확인 모달: "삭제하시겠습니까?" + [취소]/[삭제] 버튼
// isBlocked 파라미터로 분기
```

- [ ] **Step 4: SettingsScreen 구현**

pen 디자인 `RiACv` (모바일) / `AOXtJ` (PC) 참조.

섹션:
1. ACCOUNT: Google 프로필 (아바타/이메일/연결상태) + 로그아웃
2. ACCOUNTS: 명의 리스트 + 추가 + 삭제 (AccountDeleteModal)
3. APPEARANCE: 6개 색상 프리셋 원형 버튼
4. DATA REFRESH: 드롭다운 (5분/10분/15분/30분/60분, 초 단위로 저장)
5. DATA & SHEETS: CSV 내보내기 + 연결된 시트 + [변경]

CSV 내보내기: `dart:html`의 `AnchorElement`으로 Blob 다운로드. UTF-8 BOM.

시트 변경: `Navigator.push(SheetConnectScreen)` → 연결 완료 시 loadAll.

- [ ] **Step 5: app.dart의 Placeholder를 SettingsScreen으로 교체**

- [ ] **Step 6: 빌드 + 전체 테스트 + 커밋**

```bash
cd portfolio-flutter && flutter test && flutter build web --no-tree-shake-icons 2>&1 | tail -5
git add -A && git commit -m "feat: add Settings screen with account management, theme, CSV export"
```

---

## Task 9: Portfolio Screen 정리 + 최종 검증

**Files:**
- Modify: `lib/screens/portfolio_screen.dart` (+추가 버튼 제거)

- [ ] **Step 1: PortfolioScreen에서 +추가 버튼 제거**

기존 AddTransactionModal 관련 코드 제거. SegmentedFilter import 확인.

- [ ] **Step 2: 전체 테스트 실행**

```bash
cd portfolio-flutter && flutter test
```
Expected: 기존 22 + 신규 테스트 모두 통과

- [ ] **Step 3: 전체 빌드 + Chrome 실행 테스트**

```bash
cd portfolio-flutter && flutter build web --no-tree-shake-icons
```

- [ ] **Step 4: 최종 커밋**

```bash
git add -A && git commit -m "chore: remove add button from Portfolio, final Phase 2 cleanup"
```

---

## Summary

| Task | 내용 | 주요 파일 |
|------|------|----------|
| 1 | SegmentedFilter + BaseModal | segmented_filter.dart, base_modal.dart |
| 2 | ID 기반 CRUD 전환 | sheets_service.dart, portfolio_provider.dart |
| 3 | Responsive Shell + Sidebar | responsive_shell.dart, sidebar.dart, app.dart |
| 4 | History Screen + TransactionCard | history_screen.dart, transaction_card.dart |
| 5 | Ticker Search Autocomplete | ticker_search.dart |
| 6 | Transaction Modals | add/edit_transaction_modal.dart, transaction_delete_modal.dart |
| 7 | Assets Screen + Asset Modals | assets_screen.dart, asset_card.dart, add/edit_asset_modal.dart |
| 8 | Settings Screen | settings_screen.dart, account_delete_modal.dart |
| 9 | Portfolio 정리 + 최종 검증 | portfolio_screen.dart |
