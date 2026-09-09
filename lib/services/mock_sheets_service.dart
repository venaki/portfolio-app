import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../models/portfolio_snapshot.dart';
import 'sheets_service.dart';
import 'portfolio_backup.dart';
import 'mock_data.dart';

/// Real in-memory CRUD for development and tests, never a network fallback.
class MockSheetsService extends SheetsService {
  final Map<String, _MemoryPortfolio> _databases;
  final PortfolioData _seed;
  MockSheetsService({PortfolioData? data})
    : _databases = {},
      _seed =
          data ??
          (
            transactions: MockData.transactions,
            quotes: MockData.quotes,
            exchangeRate: MockData.exchangeRate,
            otherAssets: MockData.otherAssets,
            settings: MockData.settings,
          ),
      super(getAuthHeaders: () async => {});
  MockSheetsService._(this._databases, this._seed, String id)
    : super(getAuthHeaders: () async => {}, spreadsheetId: id);
  _MemoryPortfolio get _store => _databases.putIfAbsent(
    spreadsheetId ?? 'mock-spreadsheet-id',
    () => _MemoryPortfolio(_seed),
  );
  @override
  SheetsService forSpreadsheet(String id) =>
      MockSheetsService._(_databases, _seed, id);
  @override
  Future<String> createSpreadsheet() async {
    final id = 'mock-${_databases.length + 1}';
    _databases[id] = _MemoryPortfolio((
      transactions: [],
      quotes: [],
      exchangeRate: MockData.exchangeRate,
      otherAssets: [],
      settings: const AppSettings(),
    ));
    return id;
  }

  @override
  Future<PortfolioData> loadAll() async {
    spreadsheetName = '개발용 포트폴리오';
    exchangeRateValid = _store.rate.isFinite && _store.rate > 0;
    historyDirtyFrom = _store.dirty;
    return (
      transactions: [..._store.transactions],
      quotes: [..._store.quotes],
      exchangeRate: _store.rate,
      otherAssets: [..._store.assets],
      settings: _store.settings,
    );
  }

  @override
  Future<PriceData> loadPrices() async {
    exchangeRateValid = _store.rate.isFinite && _store.rate > 0;
    return (quotes: [..._store.quotes], exchangeRate: _store.rate);
  }

  @override
  Future<PriceData> forceRefreshPrices({int waitSeconds = 3}) => loadPrices();
  @override
  Future<void> addTransaction(Transaction tx) async {
    if (_store.transactions.any((t) => t.id == tx.id)) {
      throw StateError('중복 거래 ID');
    }
    _store.transactions.add(tx);
  }

  @override
  Future<void> updateTransaction(Transaction tx) async {
    final i = _store.transactions.indexWhere((t) => t.id == tx.id);
    if (i < 0) throw StateError('거래를 찾을 수 없습니다.');
    _store.transactions[i] = tx;
  }

  @override
  Future<void> deleteTransaction(String id) async =>
      _store.transactions.removeWhere((t) => t.id == id);
  @override
  Future<void> addOtherAsset(OtherAsset asset) async {
    if (_store.assets.any((a) => a.id == asset.id)) {
      throw StateError('중복 자산 ID');
    }
    _store.assets.add(asset);
  }

  @override
  Future<void> updateOtherAsset(OtherAsset asset) async {
    final i = _store.assets.indexWhere((a) => a.id == asset.id);
    if (i < 0) throw StateError('자산을 찾을 수 없습니다.');
    _store.assets[i] = asset;
  }

  @override
  Future<void> deleteOtherAsset(String id) async =>
      _store.assets.removeWhere((a) => a.id == id);
  @override
  Future<void> addPriceRow(
    String ticker,
    String market,
    String currency,
  ) async {}
  @override
  Future<void> saveSettings(AppSettings settings) async =>
      _store.settings = settings;
  @override
  Future<void> setHistoryDirtyFrom(String? date) async {
    historyDirtyFrom = date;
    _store.dirty = date;
  }

  @override
  Future<List<PortfolioSnapshot>> loadSnapshots() async =>
      [..._store.snapshots]..sort((a, b) => a.date.compareTo(b.date));
  @override
  Future<void> upsertSnapshot(PortfolioSnapshot snapshot) =>
      upsertSnapshots([snapshot]);
  @override
  Future<void> upsertSnapshots(List<PortfolioSnapshot> snapshots) async {
    for (final snapshot in snapshots) {
      final i = _store.snapshots.indexWhere((s) => s.date == snapshot.date);
      if (i < 0) {
        _store.snapshots.add(snapshot);
      } else if (snapshot.source == 'live' ||
          _store.snapshots[i].source != 'live') {
        _store.snapshots[i] = snapshot;
      }
    }
  }

  @override
  Future<HistoricalPriceImport> loadHistoricalPrices() async => _store.history;
  @override
  Future<void> saveHistoricalPrices(HistoricalPriceImport imported) async =>
      _store.history = _store.history.merge(imported);
  @override
  Future<BackfillPriceData> loadBackfillPriceData({
    required List<BackfillPriceRequest> requests,
    required DateTime start,
    required DateTime end,
    int waitSeconds = 20,
  }) async => _store.history.toBackfillData(requests);
  @override
  Future<PortfolioBackup> createBackup() async => PortfolioBackup(
    transactions: [..._store.transactions],
    otherAssets: [..._store.assets],
    settings: _store.settings,
    snapshots: [..._store.snapshots],
    historicalPrices: _store.history,
    extraSettings: {
      ..._store.extraSettings,
      if (_store.dirty != null) 'history_dirty_from': _store.dirty!,
    },
    exchangeRateSource: _store.exchangeRateSource,
  );
  @override
  Future<void> restoreBackup(PortfolioBackup backup) async {
    backup.validate();
    _store.transactions = [...backup.transactions];
    _store.assets = [...backup.otherAssets];
    _store.settings = backup.settings;
    _store.snapshots = [...backup.snapshots];
    _store.history = backup.historicalPrices;
    _store.extraSettings = {...backup.extraSettings};
    _store.exchangeRateSource = backup.exchangeRateSource;
    _store.dirty = backup.extraSettings['history_dirty_from'];
    final rate = double.tryParse(backup.exchangeRateSource);
    if (rate != null) _store.rate = rate;
  }

  @override
  Future<int> findRowById(String sheetName, String id) async =>
      sheetName == 'Transactions'
      ? _store.transactions.indexWhere((t) => t.id == id)
      : _store.assets.indexWhere((a) => a.id == id);
}

class _MemoryPortfolio {
  List<Transaction> transactions;
  List<OtherAsset> assets;
  List<StockQuote> quotes;
  AppSettings settings;
  double rate;
  String? dirty;
  Map<String, String> extraSettings = {};
  String exchangeRateSource = '=GOOGLEFINANCE("CURRENCY:USDKRW")';
  List<PortfolioSnapshot> snapshots = [];
  HistoricalPriceImport history = const HistoricalPriceImport();
  _MemoryPortfolio(PortfolioData seed)
    : transactions = [...seed.transactions],
      assets = [...seed.otherAssets],
      quotes = [...seed.quotes],
      settings = seed.settings,
      rate = seed.exchangeRate;
}
