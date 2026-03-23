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

  /// refresh prices only
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
    final newTxs = state.transactions.map((t) => t.id == tx.id ? tx : t).toList();
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
    final newOa = state.otherAssets.map((a) => a.id == asset.id ? asset : a).toList();
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

/// manage spreadsheet ID in localStorage
final spreadsheetIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('spreadsheet_id');
});

Future<void> saveSpreadsheetId(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('spreadsheet_id', id);
}
