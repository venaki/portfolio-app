import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/holdings_engine.dart';
import '../engine/portfolio_valuation.dart';
import '../engine/snapshot_engine.dart';
import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../models/portfolio_snapshot.dart';
import '../models/sheet_schema.dart';
import '../services/sheets_service.dart';
import '../services/mock_sheets_service.dart';
import '../services/portfolio_backup.dart';
import 'auth_provider.dart';
import 'portfolio_state.dart';
export 'portfolio_state.dart';

const _devMode = bool.fromEnvironment('DEV_MODE');
final dashboardViewModeProvider = StateProvider<String>((ref) => 'By Account');
final dashboardAnalysisTabProvider = StateProvider<String>((ref) => '현황');
final dashboardAllocationModeProvider = StateProvider<String>((ref) => '종목별');
final dashboardTrendRangeProvider = StateProvider<String>((ref) => '1년');

final sheetsServiceProvider = Provider<SheetsService>((ref) {
  if (_devMode) return MockSheetsService();
  final uid = ref.watch(authStateProvider.select((s) => s.valueOrNull?.uid));
  final auth = ref.read(authServiceProvider);
  final service = SheetsService(
    onUnauthorized: () {
      if (auth.currentUser?.uid == uid) auth.invalidateGoogleToken();
    },
    getAuthHeaders: () async {
      if (uid == null || auth.currentUser?.uid != uid) {
        throw StateError('로그인 계정이 변경되었습니다.');
      }
      final headers = await auth.getAuthHeaders();
      if (auth.currentUser?.uid != uid) throw StateError('로그인 계정이 변경되었습니다.');
      return headers;
    },
  );
  ref.onDispose(service.close);
  return service;
});
final portfolioProvider =
    StateNotifierProvider<PortfolioNotifier, PortfolioState>(
      (ref) => PortfolioNotifier(
        ref.watch(sheetsServiceProvider),
        loadDemo: _devMode,
      ),
    );

class PortfolioNotifier extends StateNotifier<PortfolioState> {
  final SheetsService _factory;
  SheetsService? _repository;
  final DateTime Function() _now;
  final bool enableTimer;
  Timer? _timer;
  int _generation = 0;
  Future<void>? _refreshFuture;
  Future<void> _mutationTail = Future.value();
  bool _foreground = true;
  bool _historyAvailable = false;

  PortfolioNotifier(
    this._factory, {
    bool loadDemo = false,
    this.enableTimer = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const PortfolioState()) {
    if (loadDemo) {
      unawaited(connect('mock-spreadsheet-id').catchError((Object _) {}));
    }
  }
  bool _current(int generation) => mounted && generation == _generation;
  void _check(int generation) {
    if (!_current(generation)) throw StateError('연결이 변경되어 이전 작업을 종료했습니다.');
  }

  SheetsService get _connected =>
      _repository ?? (throw StateError('스프레드시트를 먼저 연결해 주세요.'));
  void clearError() {
    if (mounted) state = state.copyWith(error: null);
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
    } else if (_repository != null) {
      _startTimer();
    }
  }

  Future<void> connect(String spreadsheetId) async {
    final candidate = _factory.forSpreadsheet(spreadsheetId), previous = state;
    final previousRepository = _repository;
    final previousHistoryAvailable = _historyAvailable;
    final generation = ++_generation;
    _timer?.cancel();
    _refreshFuture = null;
    state = state.copyWith(
      isLoading: true,
      error: null,
      isSaving: false,
      isBackfilling: false,
    );
    try {
      final data = await candidate.loadAll();
      _check(generation);
      final history = await _readHistory(candidate, generation);
      _check(generation);
      _repository = candidate;
      _historyAvailable = history.warning == null;
      state = _loadedState(
        candidate,
        data,
        history.snapshots,
      ).copyWith(error: history.warning, isLoading: true);
      await _syncSnapshot(candidate, generation);
      _check(generation);
      state = state.copyWith(isLoading: false);
      _startTimer();
    } catch (e) {
      if (_current(generation)) {
        _repository = previousRepository;
        _historyAvailable = previousHistoryAvailable;
        state = previous.copyWith(
          isLoading: false,
          isSaving: false,
          error: _message(e),
        );
        _startTimer();
      }
      rethrow;
    }
  }

  Future<({List<PortfolioSnapshot> snapshots, String? warning})> _readHistory(
    SheetsService repository,
    int generation, {
    List<PortfolioSnapshot> previous = const [],
  }) async {
    try {
      final snapshots = await repository.loadSnapshots();
      _check(generation);
      return (
        snapshots: snapshots,
        warning: repository.snapshotIssues.isEmpty
            ? null
            : '일부 과거 기록을 읽지 못했습니다. ${repository.snapshotIssues.take(3).join(' ')}',
      );
    } catch (error) {
      _check(generation);
      return (
        snapshots: previous,
        warning: '자산은 불러왔지만 과거 기록을 읽지 못했습니다. ${_message(error)}',
      );
    }
  }

  Future<String> createAndConnect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final id = await _factory.createSpreadsheet();
      if (!mounted) throw StateError('연결이 종료되었습니다.');
      await connect(id);
      return id;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: _message(e));
      rethrow;
    }
  }

  PortfolioState _loadedState(
    SheetsService repository,
    PortfolioData data,
    List<PortfolioSnapshot> snapshots,
  ) {
    final replay = replayPortfolio(
      data.transactions,
      throughDate: dateKey(_now()),
    );
    final issues = <String>[
      ...repository.dataIssues,
      ...replayPortfolio(data.transactions).issues.map((i) => i.toString()),
      ...validateOtherAssetLedger(data.otherAssets).map((i) => i.toString()),
    ];
    for (final account in {
      ...data.transactions.map((t) => t.account),
      ...data.otherAssets.map((a) => a.account),
    }) {
      if (!data.settings.accounts.contains(account)) {
        issues.add('설정에 등록되지 않은 명의: $account');
      }
    }
    final quotes = {
      for (final quote in data.quotes)
        quote.ticker: quote.copyWith(fetchedAt: _now()),
    };
    final stale = [
      for (final h in replay.holdings)
        if (quotes[h.ticker]?.hasValidPrice != true) h.ticker,
      if (!repository.exchangeRateValid) 'USDKRW',
    ];
    return PortfolioState(
      asOfDate: dateKey(_now()),
      transactions: data.transactions,
      holdings: replay.holdings,
      quotes: quotes,
      exchangeRate: data.exchangeRate,
      otherAssets: data.otherAssets,
      snapshots: snapshots,
      settings: data.settings,
      spreadsheetId: repository.spreadsheetId,
      spreadsheetName: repository.spreadsheetName,
      dataIssues: issues,
      staleTickers: stale,
      historyDirtyFrom: repository.historyDirtyFrom,
      lastUpdated: stale.isEmpty ? _now() : null,
    );
  }

  Future<void> loadAll() async {
    final repository = _connected, generation = _generation;
    if (state.isLoading || state.isSaving || state.isBackfilling) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.loadAll();
      _check(generation);
      final history = await _readHistory(
        repository,
        generation,
        previous: state.snapshots,
      );
      _check(generation);
      _historyAvailable = history.warning == null;
      state = _loadedState(
        repository,
        data,
        history.snapshots,
      ).copyWith(error: history.warning, isLoading: true);
      await _syncSnapshot(repository, generation);
      _check(generation);
      state = state.copyWith(isLoading: false);
      _startTimer();
    } catch (e) {
      if (_current(generation)) {
        state = state.copyWith(isLoading: false, error: _message(e));
      }
    }
  }

  Future<void> refreshPrices({bool force = false}) {
    if (_refreshFuture != null) return _refreshFuture!;
    if (_repository == null ||
        state.isLoading ||
        state.isSaving ||
        state.isBackfilling) {
      return Future.value();
    }
    final generation = _generation;
    final future = _refresh(_connected, generation);
    _refreshFuture = future;
    unawaited(
      future.whenComplete(() {
        if (_current(generation)) _refreshFuture = null;
      }),
    );
    return future;
  }

  Future<void> _refresh(SheetsService repository, int generation) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await repository.loadPrices();
      _check(generation);
      _applyPrices(repository, data);
      await _syncSnapshot(repository, generation);
      _check(generation);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (_current(generation)) {
        state = state.copyWith(isLoading: false, error: _message(e));
      }
    }
  }

  void _applyPrices(SheetsService repository, PriceData data) {
    final incoming = {for (final quote in data.quotes) quote.ticker: quote};
    final merged = <String, StockQuote>{};
    final stale = <String>[];
    for (final ticker in {
      ...state.quotes.keys,
      ...incoming.keys,
      ...state.holdings.map((h) => h.ticker),
    }) {
      final quote = incoming[ticker], previous = state.quotes[ticker];
      if (quote?.hasValidPrice == true) {
        merged[ticker] = quote!.copyWith(isStale: false, fetchedAt: _now());
      } else if (previous?.hasValidPrice == true) {
        merged[ticker] = previous!.copyWith(isStale: true);
        stale.add(ticker);
      } else {
        if (quote != null) merged[ticker] = quote;
        stale.add(ticker);
      }
    }
    if (!repository.exchangeRateValid) stale.add('USDKRW');
    state = state.copyWith(
      asOfDate: dateKey(_now()),
      holdings: replayPortfolio(
        state.transactions,
        throughDate: dateKey(_now()),
      ).holdings,
      quotes: merged,
      exchangeRate: repository.exchangeRateValid
          ? data.exchangeRate
          : state.exchangeRate,
      staleTickers: stale,
      lastUpdated: stale.isEmpty ? _now() : state.lastUpdated,
      error: stale.isEmpty
          ? null
          : '일부 시세·환율을 확인하지 못했습니다. 이전 정상값을 유지하고 오늘 기록은 갱신하지 않았습니다.',
    );
  }

  Future<void> _mutate(
    Future<void> Function(SheetsService, int) action, {
    bool allowInvalidLedger = false,
  }) {
    final generation = _generation;
    final future = _mutationTail.then((_) async {
      _check(generation);
      if (!allowInvalidLedger && state.dataIssues.isNotEmpty) {
        throw StateError('원장의 오류를 시트에서 수정한 후 다시 불러와 주세요.');
      }
      if (state.isLoading || state.isBackfilling) {
        throw StateError('진행 중인 작업이 끝난 후 시도해 주세요.');
      }
      final repository = _connected;
      state = state.copyWith(isSaving: true, error: null);
      try {
        await action(repository, generation);
        _check(generation);
      } catch (e) {
        if (_current(generation)) state = state.copyWith(error: _message(e));
        rethrow;
      } finally {
        if (_current(generation)) state = state.copyWith(isSaving: false);
      }
    });
    _mutationTail = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  void _validateLedger(
    List<Transaction> transactions,
    List<OtherAsset> assets,
  ) {
    final errors = [
      ...replayPortfolio(transactions).issues.map((i) => i.toString()),
      ...validateOtherAssetLedger(assets).map((i) => i.toString()),
    ];
    if (errors.isNotEmpty) throw FormatException(errors.take(5).join('\n'));
  }

  void _validateAccount(String account, {String broker = ''}) {
    if (!state.settings.accounts.contains(account)) {
      throw const FormatException('등록된 명의를 선택해 주세요.');
    }
    if (broker.isNotEmpty && !state.settings.brokers.contains(broker)) {
      throw const FormatException('등록된 증권사를 선택해 주세요.');
    }
  }

  Future<void> _markDirty(
    SheetsService repository,
    int generation,
    String date,
  ) async {
    _check(generation);
    if (date.compareTo(dateKey(_now())) >= 0) return;
    final dirty = state.historyDirtyFrom;
    final earliest = dirty != null && dirty.compareTo(date) < 0 ? dirty : date;
    state = state.copyWith(historyDirtyFrom: earliest);
    await repository.setHistoryDirtyFrom(earliest);
    _check(generation);
  }

  Future<void> _afterMutation(SheetsService repository, int generation) async {
    // A committed ledger write remains successful if a subsequent price/snapshot read fails.
    try {
      final prices = await repository.loadPrices();
      _check(generation);
      _applyPrices(repository, prices);
      await _syncSnapshot(repository, generation);
    } catch (e) {
      if (_current(generation)) {
        state = state.copyWith(
          error: '저장은 완료했지만 평가 갱신에 실패했습니다. ${_message(e)}',
        );
      }
    }
  }

  Future<void> addTransaction(Transaction tx) => _mutate((
    repository,
    generation,
  ) async {
    _validateAccount(tx.account, broker: tx.broker);
    final next = [...state.transactions, tx];
    _validateLedger(next, state.otherAssets);
    // Safe to create a derived price row first; never report a committed ledger as failed.
    await repository.addPriceRow(
      tx.ticker,
      tx.market.toSheetValue(),
      tx.currency == Currency.krw ? 'KRW' : 'USD',
    );
    _check(generation);
    await _markDirty(repository, generation, tx.date);
    await repository.addTransaction(tx);
    _check(generation);
    state = state.copyWith(
      transactions: next,
      holdings: replayPortfolio(next, throughDate: dateKey(_now())).holdings,
    );
    await _afterMutation(repository, generation);
  });
  Future<void> updateTransaction(Transaction tx) => _mutate((
    repository,
    generation,
  ) async {
    _validateAccount(tx.account, broker: tx.broker);
    final old = state.transactions.firstWhere((t) => t.id == tx.id);
    final next = state.transactions.map((t) => t.id == tx.id ? tx : t).toList();
    _validateLedger(next, state.otherAssets);
    await repository.addPriceRow(
      tx.ticker,
      tx.market.toSheetValue(),
      tx.currency == Currency.krw ? 'KRW' : 'USD',
    );
    _check(generation);
    await _markDirty(
      repository,
      generation,
      old.date.compareTo(tx.date) < 0 ? old.date : tx.date,
    );
    await repository.updateTransaction(tx);
    _check(generation);
    state = state.copyWith(
      transactions: next,
      holdings: replayPortfolio(next, throughDate: dateKey(_now())).holdings,
    );
    await _afterMutation(repository, generation);
  });
  Future<void> deleteTransaction(String id) => _mutate((
    repository,
    generation,
  ) async {
    final old = state.transactions.firstWhere((t) => t.id == id),
        next = state.transactions.where((t) => t.id != id).toList();
    _validateLedger(next, state.otherAssets);
    await _markDirty(repository, generation, old.date);
    await repository.deleteTransaction(id);
    _check(generation);
    state = state.copyWith(
      transactions: next,
      holdings: replayPortfolio(next, throughDate: dateKey(_now())).holdings,
    );
    await _afterMutation(repository, generation);
  });
  Future<void> addOtherAsset(OtherAsset asset) =>
      _mutate((repository, generation) async {
        _validateAccount(asset.account);
        final next = [...state.otherAssets, asset];
        _validateLedger(state.transactions, next);
        await _markDirty(repository, generation, asset.date);
        await repository.addOtherAsset(asset);
        _check(generation);
        state = state.copyWith(otherAssets: next);
        await _afterMutation(repository, generation);
      });
  Future<void> updateOtherAsset(OtherAsset asset) =>
      _mutate((repository, generation) async {
        _validateAccount(asset.account);
        final old = state.otherAssets.firstWhere((a) => a.id == asset.id);
        final next = state.otherAssets
            .map((a) => a.id == asset.id ? asset : a)
            .toList();
        _validateLedger(state.transactions, next);
        await _markDirty(
          repository,
          generation,
          old.date.compareTo(asset.date) < 0 ? old.date : asset.date,
        );
        await repository.updateOtherAsset(asset);
        _check(generation);
        state = state.copyWith(otherAssets: next);
        await _afterMutation(repository, generation);
      });
  Future<void> deleteOtherAsset(String id) =>
      _mutate((repository, generation) async {
        final old = state.otherAssets.firstWhere((a) => a.id == id),
            next = state.otherAssets.where((a) => a.id != id).toList();
        _validateLedger(state.transactions, next);
        await _markDirty(repository, generation, old.date);
        await repository.deleteOtherAsset(id);
        _check(generation);
        state = state.copyWith(otherAssets: next);
        await _afterMutation(repository, generation);
      });
  Future<void> updateSettings(AppSettings settings) =>
      _mutate((repository, generation) async {
        if (settings.validationErrors.isNotEmpty) {
          throw FormatException(settings.validationErrors.join(' '));
        }
        for (final name in {
          ...state.transactions.map((t) => t.account),
          ...state.otherAssets.map((a) => a.account),
        }) {
          if (!settings.accounts.contains(name)) {
            throw FormatException('$name 명의에 남아 있는 거래·자산을 먼저 이관해 주세요.');
          }
        }
        for (final tx in state.transactions) {
          if (tx.broker.isNotEmpty && !settings.brokers.contains(tx.broker)) {
            throw FormatException('${tx.broker} 증권사에 거래가 남아 있습니다.');
          }
        }
        await repository.saveSettings(settings);
        _check(generation);
        state = state.copyWith(settings: settings);
        _startTimer();
      });

  Future<void> _syncSnapshot(SheetsService repository, int generation) async {
    _check(generation);
    if (!_historyAvailable ||
        state.dataIssues.isNotEmpty ||
        state.staleTickers.isNotEmpty) {
      return;
    }
    final valuation = evaluatePortfolio(
      holdings: state.holdings,
      otherAssets: state.consolidatedOtherAssets,
      quotes: state.quotes,
      exchangeRate: state.exchangeRate,
    );
    final snapshot = buildCurrentSnapshot(
      valuation: valuation,
      exchangeRate: state.exchangeRate,
      now: _now(),
    );
    if (snapshot == null) return;
    try {
      await repository.upsertSnapshot(snapshot);
      _check(generation);
      final updated = [
        ...state.snapshots.where((s) => s.date != snapshot.date),
        snapshot,
      ]..sort((a, b) => a.date.compareTo(b.date));
      state = state.copyWith(snapshots: updated);
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
          error: '자산은 갱신했지만 오늘 기록을 저장하지 못했습니다. ${_message(error)}',
        );
      }
    }
  }

  Future<void> backfillOneYearSnapshots() async {
    if (state.isBackfilling || state.isSaving || state.isLoading) return;
    if (state.dataIssues.isNotEmpty) {
      state = state.copyWith(error: '원장 오류를 수정한 후 추이를 복원해 주세요.');
      return;
    }
    final repository = _connected, generation = _generation;
    state = state.copyWith(
      isBackfilling: true,
      error: null,
      backfillMessage: '가져온 과거 가격과 환율로 기록을 계산하고 있습니다.',
    );
    try {
      final now = _now(),
          end = DateTime(
            _now().year,
            _now().month,
            _now().day,
          ).subtract(const Duration(days: 1));
      var start = end.subtract(const Duration(days: 365));
      final dates = [
        ...state.transactions.map((t) => t.date),
        ...state.otherAssets.map((a) => a.date),
      ]..sort();
      if (dates.isNotEmpty && DateTime.parse(dates.first).isAfter(start)) {
        start = DateTime.parse(dates.first);
      }
      final data = await repository.loadBackfillPriceData(
        requests: [
          for (final t in state.transactions)
            BackfillPriceRequest(
              ticker: t.ticker,
              market: t.market.toSheetValue(),
            ),
        ],
        start: start,
        end: end,
      );
      _check(generation);
      final built = buildHistoricalSnapshots(
        transactions: state.transactions,
        otherAssets: state.otherAssets,
        pricesByTicker: data.pricesByTicker,
        exchangeRates: data.exchangeRates,
        start: start,
        end: end,
        createdAt: now,
      );
      if (built.snapshots.isEmpty) {
        throw FormatException(
          '필요한 과거 가격·환율이 없습니다. 가격 파일을 먼저 가져와 주세요. ${built.issues.take(3).join(' ')}',
        );
      }
      await repository.upsertSnapshots(built.snapshots);
      _check(generation);
      final snapshots = await repository.loadSnapshots();
      _check(generation);
      // Historical observations are preserved. A changed ledger does not silently rewrite them.
      if (built.isComplete &&
          state.historyDirtyFrom != null &&
          state.historyDirtyFrom!.compareTo(dateKey(start)) >= 0 &&
          !snapshots.any(
            (s) =>
                s.source == 'live' &&
                s.date.compareTo(state.historyDirtyFrom!) >= 0 &&
                s.date.compareTo(dateKey(end)) <= 0,
          )) {
        await repository.setHistoryDirtyFrom(null);
        _check(generation);
        state = state.copyWith(historyDirtyFrom: null);
      }
      state = state.copyWith(
        snapshots: snapshots,
        isBackfilling: false,
        backfillMessage:
            '${built.snapshots.length}일의 계산을 완료했습니다. 기존 실측 기록은 보존합니다.${built.issues.isEmpty ? '' : ' 누락 ${built.issues.length}건: ${built.issues.take(3).join(' ')}'}',
      );
    } catch (e) {
      if (_current(generation)) {
        state = state.copyWith(
          isBackfilling: false,
          error: _message(e),
          backfillMessage: '추이 복원을 완료하지 못했습니다. ${_message(e)}',
        );
      }
    }
  }

  Future<PortfolioBackup> createBackup() async {
    final generation = _generation, repository = _connected;
    if (state.isLoading || state.isSaving || state.isBackfilling) {
      throw StateError('진행 중인 작업이 끝난 후 백업해 주세요.');
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final backup = await _factory
          .forSpreadsheet(repository.spreadsheetId!)
          .createBackup();
      _check(generation);
      backup.validate();
      return backup;
    } catch (error) {
      if (_current(generation)) state = state.copyWith(error: _message(error));
      rethrow;
    } finally {
      if (_current(generation)) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> restoreBackup(PortfolioBackup backup) => _mutate((
    repository,
    generation,
  ) async {
    backup.validate();
    await repository.restoreBackup(backup);
    _check(generation);
    // The replacement already committed; a failed follow-up read must not invite
    // a second restore or leave the previous ledger visible under the new data.
    state = PortfolioState(
      asOfDate: dateKey(_now()),
      transactions: backup.transactions,
      holdings: replayPortfolio(
        backup.transactions,
        throughDate: dateKey(_now()),
      ).holdings,
      otherAssets: backup.otherAssets,
      settings: backup.settings,
      snapshots: backup.snapshots,
      historyDirtyFrom: backup.extraSettings['history_dirty_from'],
      spreadsheetId: repository.spreadsheetId,
      spreadsheetName: repository.spreadsheetName,
      isSaving: true,
      staleTickers: [
        'USDKRW',
        ...backup.transactions.map((t) => t.ticker).toSet(),
      ],
    );
    try {
      final data = await repository.loadAll();
      _check(generation);
      final history = await _readHistory(
        repository,
        generation,
        previous: backup.snapshots,
      );
      _check(generation);
      _historyAvailable = history.warning == null;
      state = _loadedState(
        repository,
        data,
        history.snapshots,
      ).copyWith(isSaving: true, error: history.warning);
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
          error: '복원은 완료했습니다. 시세를 다시 불러와 주세요. ${_message(error)}',
        );
      }
    }
    _startTimer();
  }, allowInvalidLedger: true);
  Future<void> importHistoricalPrices(HistoricalPriceImport data) =>
      _mutate((repository, generation) async {
        await repository.saveHistoricalPrices(data);
        _check(generation);
        state = state.copyWith(
          backfillMessage: '${data.summary}을 저장했습니다. 추이 복원을 실행해 주세요.',
        );
      });
  void _startTimer() {
    _timer?.cancel();
    if (!mounted || !enableTimer || !_foreground || _repository == null) return;
    _timer = Timer.periodic(
      Duration(seconds: state.settings.refreshInterval.clamp(30, 86400)),
      (_) {
        if (mounted &&
            !state.isLoading &&
            !state.isSaving &&
            !state.isBackfilling) {
          unawaited(refreshPrices());
        }
      },
    );
  }

  static String _message(Object error) => error is FormatException
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');
  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}

final spreadsheetIdProvider = FutureProvider<String?>((ref) async {
  if (_devMode) return 'mock-spreadsheet-id';
  final uid = ref.watch(authStateProvider.select((s) => s.valueOrNull?.uid));
  if (uid == null) return null;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('spreadsheet_id:$uid');
});
Future<void> saveSpreadsheetId(String id, {String? userId}) async {
  if (_devMode) return;
  final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('로그인이 필요합니다.');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('spreadsheet_id:$uid', id);
}
