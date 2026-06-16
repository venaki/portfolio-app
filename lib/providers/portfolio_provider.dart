import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../models/portfolio_snapshot.dart';
import '../services/sheets_service.dart';
import '../services/mock_sheets_service.dart';
import '../services/mock_data.dart';
import '../engine/holdings_engine.dart';
import '../engine/calculations.dart';
import 'auth_provider.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');

/// 대시보드 뷰 모드 (By Account / By Type)
final dashboardViewModeProvider = StateProvider<String>((ref) => 'By Account');

/// 대시보드 분석 탭 (현황 / 추이 / 비중)
final dashboardAnalysisTabProvider = StateProvider<String>((ref) => '현황');

/// 대시보드 비중 탭 뷰 모드 (종목별 / 유형별 / 계좌별)
final dashboardAllocationModeProvider = StateProvider<String>((ref) => '종목별');

/// 대시보드 추이 탭 기간 필터
final dashboardTrendRangeProvider = StateProvider<String>((ref) => '1년');

final sheetsServiceProvider = Provider<SheetsService>((ref) {
  if (_devMode) return MockSheetsService();
  final authService = ref.read(authServiceProvider);
  return SheetsService(getAuthHeaders: authService.getAuthHeaders);
});

class PortfolioState {
  final List<Transaction> transactions;
  final List<Holding> holdings;
  final Map<String, StockQuote> quotes;
  final double exchangeRate;
  final List<OtherAsset> otherAssets;
  final List<PortfolioSnapshot> snapshots;
  final AppSettings settings;
  final bool isLoading;
  final bool isBackfilling;
  final String? backfillMessage;
  final String? error;
  final DateTime? lastUpdated;

  const PortfolioState({
    this.transactions = const [],
    this.holdings = const [],
    this.quotes = const {},
    this.exchangeRate = 1450,
    this.otherAssets = const [],
    this.snapshots = const [],
    this.settings = const AppSettings(),
    this.isLoading = false,
    this.isBackfilling = false,
    this.backfillMessage,
    this.error,
    this.lastUpdated,
  });

  /// name + account + category 기준 통합 자산
  List<ConsolidatedAsset> get consolidatedOtherAssets =>
      consolidateOtherAssets(otherAssets);

  PortfolioState copyWith({
    List<Transaction>? transactions,
    List<Holding>? holdings,
    Map<String, StockQuote>? quotes,
    double? exchangeRate,
    List<OtherAsset>? otherAssets,
    List<PortfolioSnapshot>? snapshots,
    AppSettings? settings,
    bool? isLoading,
    bool? isBackfilling,
    String? backfillMessage,
    String? error,
    DateTime? lastUpdated,
  }) {
    return PortfolioState(
      transactions: transactions ?? this.transactions,
      holdings: holdings ?? this.holdings,
      quotes: quotes ?? this.quotes,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      otherAssets: otherAssets ?? this.otherAssets,
      snapshots: snapshots ?? this.snapshots,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isBackfilling: isBackfilling ?? this.isBackfilling,
      backfillMessage: backfillMessage ?? this.backfillMessage,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

final portfolioProvider =
    StateNotifierProvider<PortfolioNotifier, PortfolioState>((ref) {
      return PortfolioNotifier(ref.read(sheetsServiceProvider));
    });

class PortfolioNotifier extends StateNotifier<PortfolioState> {
  final SheetsService _sheets;
  Timer? _refreshTimer;

  PortfolioNotifier(this._sheets) : super(const PortfolioState()) {
    if (_devMode) _loadMockData();
  }

  void _loadMockData() {
    final data = MockData.transactions;
    final holdings = replayTransactions(data);
    final quotesMap = {for (final q in MockData.quotes) q.ticker: q};
    state = PortfolioState(
      transactions: data,
      holdings: holdings,
      quotes: quotesMap,
      exchangeRate: MockData.exchangeRate,
      otherAssets: MockData.otherAssets,
      settings: MockData.settings,
      lastUpdated: DateTime.now(),
    );
    _syncTodaySnapshot();
  }

  /// connect spreadsheet
  Future<void> connect(String spreadsheetId) async {
    _sheets.setSpreadsheetId(spreadsheetId);
    await loadAll();
  }

  /// create and connect new spreadsheet
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

  /// load all data
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _sheets.loadAll();
      final holdings = replayTransactions(data.transactions);
      final quotesMap = {for (final q in data.quotes) q.ticker: q};
      final snapshots = await _sheets.loadSnapshots();

      state = state.copyWith(
        transactions: data.transactions,
        holdings: holdings,
        quotes: quotesMap,
        exchangeRate: data.exchangeRate,
        otherAssets: data.otherAssets,
        snapshots: snapshots,
        settings: data.settings,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      await _syncTodaySnapshot();
      _startRefreshTimer(data.settings.refreshInterval);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// refresh prices only
  Future<void> refreshPrices({bool force = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = force
          ? await _sheets.forceRefreshPrices(
              waitSeconds: state.settings.forceRefreshWait,
            )
          : await _sheets.loadPrices();
      final quotesMap = {for (final q in data.quotes) q.ticker: q};
      state = state.copyWith(
        quotes: quotesMap,
        exchangeRate: data.exchangeRate,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      await _syncTodaySnapshot();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// add transaction
  Future<void> addTransaction(Transaction tx) async {
    await _sheets.addTransaction(tx);
    // update local state immediately
    final newTxs = [...state.transactions, tx];
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);

    // add price row if new ticker
    final existingTickers = state.quotes.keys.toSet();
    if (!existingTickers.contains(tx.ticker)) {
      await _sheets.addPriceRow(
        tx.ticker,
        tx.market.toSheetValue(),
        tx.currency == Currency.krw ? 'KRW' : 'USD',
      );
    }

    // 시세 갱신 (GOOGLEFINANCE 수식 반영 대기)
    Future.delayed(const Duration(seconds: 2), () => refreshPrices());
  }

  /// update transaction
  Future<void> updateTransaction(Transaction tx) async {
    await _sheets.updateTransaction(tx);
    final newTxs = state.transactions
        .map((t) => t.id == tx.id ? tx : t)
        .toList();
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);
    refreshPrices();
  }

  /// delete transaction
  Future<void> deleteTransaction(String id) async {
    await _sheets.deleteTransaction(id);
    final newTxs = state.transactions.where((t) => t.id != id).toList();
    final newHoldings = replayTransactions(newTxs);
    state = state.copyWith(transactions: newTxs, holdings: newHoldings);
    refreshPrices();
  }

  Future<void> addOtherAsset(OtherAsset asset) async {
    await _sheets.addOtherAsset(asset);
    state = state.copyWith(otherAssets: [...state.otherAssets, asset]);
    refreshPrices();
  }

  Future<void> updateOtherAsset(OtherAsset asset) async {
    await _sheets.updateOtherAsset(asset);
    final newOa = state.otherAssets
        .map((a) => a.id == asset.id ? asset : a)
        .toList();
    state = state.copyWith(otherAssets: newOa);
    refreshPrices();
  }

  Future<void> deleteOtherAsset(String id) async {
    await _sheets.deleteOtherAsset(id);
    final newOa = state.otherAssets.where((a) => a.id != id).toList();
    state = state.copyWith(otherAssets: newOa);
    refreshPrices();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final oldInterval = state.settings.refreshInterval;
    await _sheets.saveSettings(newSettings);
    state = state.copyWith(settings: newSettings);
    if (newSettings.refreshInterval != oldInterval) {
      _startRefreshTimer(newSettings.refreshInterval);
    }
  }

  Future<void> backfillOneYearSnapshots() async {
    if (state.isBackfilling) return;
    state = state.copyWith(
      isBackfilling: true,
      backfillMessage: '과거 가격을 조회하고 있어요. 몇 분 걸릴 수 있습니다.',
      error: null,
    );

    try {
      final now = DateTime.now();
      final end = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final oneYearStart = end.subtract(const Duration(days: 365));
      final portfolioStart = _portfolioStartDate();
      final start = portfolioStart != null && portfolioStart.isAfter(oneYearStart)
          ? portfolioStart
          : oneYearStart;
      final requests = _backfillPriceRequests();

      final priceData = await _sheets.loadBackfillPriceData(
        requests: requests,
        start: start,
        end: end,
      );

      final snapshots = _buildBackfillSnapshots(priceData, start, end);
      state = state.copyWith(
        backfillMessage: '${snapshots.length}개 스냅샷을 저장하고 있어요.',
      );
      await _sheets.upsertSnapshots(snapshots);

      final latest = await _sheets.loadSnapshots();
      final failed = priceData.failedSymbols.isEmpty
          ? ''
          : ' 일부 가격 조회 실패: ${priceData.failedSymbols.join(', ')}';
      state = state.copyWith(
        snapshots: latest,
        isBackfilling: false,
        backfillMessage: '최근 1년 추이 복원을 완료했어요.$failed',
      );
    } catch (e) {
      state = state.copyWith(
        isBackfilling: false,
        backfillMessage: '추이 복원에 실패했습니다. ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  void _startRefreshTimer(int intervalSeconds) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => refreshPrices(),
    );
  }

  Future<void> _syncTodaySnapshot() async {
    final existingSnapshots = await _sheets.loadSnapshots();
    final snapshot = _buildCurrentSnapshot(existingSnapshots);
    await _sheets.upsertSnapshot(snapshot);
    final snapshots = await _sheets.loadSnapshots();
    state = state.copyWith(snapshots: snapshots);
  }

  List<BackfillPriceRequest> _backfillPriceRequests() {
    final requests = <String, BackfillPriceRequest>{};
    for (final tx in state.transactions) {
      requests[tx.ticker] = BackfillPriceRequest(
        ticker: tx.ticker,
        market: tx.market.toSheetValue(),
      );
    }
    return requests.values.toList();
  }

  DateTime? _portfolioStartDate() {
    final dates = <String>[
      ...state.transactions.map((tx) => tx.date),
      ...state.otherAssets.map((asset) => asset.date),
    ]..removeWhere((date) => date.isEmpty);
    if (dates.isEmpty) return null;
    dates.sort();
    return DateTime.tryParse(dates.first);
  }

  List<PortfolioSnapshot> _buildBackfillSnapshots(
    BackfillPriceData priceData,
    DateTime start,
    DateTime end,
  ) {
    final snapshots = <PortfolioSnapshot>[];
    PortfolioSnapshot? previous;
    final createdAt = DateTime.now().toIso8601String();

    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final key = _dateKey(date);
      final txs = state.transactions
          .where((tx) => tx.date.compareTo(key) <= 0)
          .toList();
      final holdings = replayTransactions(txs);

      double totalValueKRW = 0;
      double totalCostKRW = 0;

      for (final holding in holdings) {
        final price = _seriesValueNearDate(
          priceData.pricesByTicker[holding.ticker] ?? const {},
          date,
          start,
          end,
        );
        if (price == null) {
          throw Exception('과거 가격을 찾을 수 없습니다: ${holding.ticker} $key');
        }
        final rate = holding.currency == Currency.krw
            ? 1.0
            : (_seriesValueNearDate(
                    priceData.exchangeRates,
                    date,
                    start,
                    end,
                  ) ??
                  state.exchangeRate);
        totalValueKRW += calcTotalValueKRW(holding, price, rate);
        totalCostKRW += calcCostKRW(holding);
      }

      final otherAssets = state.otherAssets
          .where((asset) => asset.date.compareTo(key) <= 0)
          .toList();
      for (final ca in consolidateOtherAssets(otherAssets)) {
        final raw = ca.category == AssetCategory.loan
            ? -ca.totalValue.abs()
            : ca.totalValue;
        final value = ca.currency == Currency.krw
            ? raw
            : raw *
                  (_seriesValueNearDate(
                        priceData.exchangeRates,
                        date,
                        start,
                        end,
                      ) ??
                      state.exchangeRate);
        totalValueKRW += value;
        totalCostKRW += value;
      }

      final profitKRW = totalValueKRW - totalCostKRW;
      final profitPct = totalCostKRW > 0 ? profitKRW / totalCostKRW * 100 : 0.0;
      final dailyChangeKRW = previous == null
          ? 0.0
          : totalValueKRW - previous.totalValueKRW;
      final dailyChangePct = previous != null && previous.totalValueKRW > 0
          ? dailyChangeKRW / previous.totalValueKRW * 100
          : 0.0;

      final snapshot = PortfolioSnapshot(
        id: 'snapshot-$key',
        date: key,
        totalValueKRW: totalValueKRW,
        totalCostKRW: totalCostKRW,
        profitKRW: profitKRW,
        profitPct: profitPct,
        dailyChangeKRW: dailyChangeKRW,
        dailyChangePct: dailyChangePct,
        exchangeRate:
            _seriesValueNearDate(priceData.exchangeRates, date, start, end) ??
            state.exchangeRate,
        source: 'backfill',
        createdAt: createdAt,
      );
      snapshots.add(snapshot);
      previous = snapshot;
    }

    return snapshots;
  }

  double? _seriesValueNearDate(
    Map<String, double> series,
    DateTime date,
    DateTime minDate,
    DateTime maxDate,
  ) {
    for (
      var cursor = date;
      !cursor.isBefore(minDate);
      cursor = cursor.subtract(const Duration(days: 1))
    ) {
      final value = series[_dateKey(cursor)];
      if (value != null) return value;
    }
    for (
      var cursor = date.add(const Duration(days: 1));
      !cursor.isAfter(maxDate) && cursor.difference(date).inDays <= 7;
      cursor = cursor.add(const Duration(days: 1))
    ) {
      final value = series[_dateKey(cursor)];
      if (value != null) return value;
    }
    return null;
  }

  PortfolioSnapshot _buildCurrentSnapshot(List<PortfolioSnapshot> snapshots) {
    double totalValueKRW = 0;
    double totalCostKRW = 0;
    double stockDailyChangeKRW = 0;
    double stockYestValueKRW = 0;

    for (final h in state.holdings) {
      final quote = state.quotes[h.ticker];
      final price = quote?.price ?? 0;
      final closeYest = quote?.closeYest ?? price;
      totalValueKRW += calcTotalValueKRW(h, price, state.exchangeRate);
      totalCostKRW += calcCostKRW(h);
      stockDailyChangeKRW += calcDailyChangeKRW(
        h,
        price,
        closeYest,
        state.exchangeRate,
      );
      stockYestValueKRW += calcTotalValueKRW(h, closeYest, state.exchangeRate);
    }

    for (final ca in state.consolidatedOtherAssets) {
      final raw = ca.category == AssetCategory.loan
          ? -ca.totalValue.abs()
          : ca.totalValue;
      final value = ca.currency == Currency.krw
          ? raw
          : raw * state.exchangeRate;
      totalValueKRW += value;
      totalCostKRW += value;
    }

    final today = _todayKey();
    final previous =
        snapshots
            .where((snapshot) => snapshot.date.compareTo(today) < 0)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final previousSnapshot = previous.isEmpty ? null : previous.first;
    final dailyChangeKRW = previousSnapshot == null
        ? stockDailyChangeKRW
        : totalValueKRW - previousSnapshot.totalValueKRW;
    final dailyBase = previousSnapshot?.totalValueKRW ?? stockYestValueKRW;
    final dailyChangePct = dailyBase > 0
        ? dailyChangeKRW / dailyBase * 100
        : 0.0;
    final profitKRW = totalValueKRW - totalCostKRW;
    final profitPct = totalCostKRW > 0 ? profitKRW / totalCostKRW * 100 : 0.0;
    final now = DateTime.now();

    return PortfolioSnapshot(
      id: 'snapshot-$today',
      date: today,
      totalValueKRW: totalValueKRW,
      totalCostKRW: totalCostKRW,
      profitKRW: profitKRW,
      profitPct: profitPct,
      dailyChangeKRW: dailyChangeKRW,
      dailyChangePct: dailyChangePct,
      exchangeRate: state.exchangeRate,
      source: 'live',
      createdAt: now.toIso8601String(),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return _dateKey(now);
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// manage spreadsheet ID in localStorage
final spreadsheetIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('spreadsheet_id');
});

Future<void> saveSpreadsheetId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('spreadsheet_id', id);
}
