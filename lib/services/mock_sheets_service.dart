import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import '../models/portfolio_snapshot.dart';
import 'sheets_service.dart';
import 'mock_data.dart';

/// Dev 모드용 MockSheetsService — API 호출 없이 로컬 메모리로 동작
class MockSheetsService extends SheetsService {
  MockSheetsService() : super(getAuthHeaders: () async => {});

  final List<PortfolioSnapshot> _snapshots = [];

  @override
  Future<String> createSpreadsheet() async => 'mock-spreadsheet-id';

  @override
  Future<
    ({
      List<Transaction> transactions,
      List<StockQuote> quotes,
      double exchangeRate,
      List<OtherAsset> otherAssets,
      AppSettings settings,
    })
  >
  loadAll() async {
    return (
      transactions: MockData.transactions,
      quotes: MockData.quotes,
      exchangeRate: MockData.exchangeRate,
      otherAssets: MockData.otherAssets,
      settings: MockData.settings,
    );
  }

  @override
  Future<({List<StockQuote> quotes, double exchangeRate})> loadPrices() async {
    // no-op: 고정 시세 반환
    return (quotes: MockData.quotes, exchangeRate: MockData.exchangeRate);
  }

  @override
  Future<({List<StockQuote> quotes, double exchangeRate})> forceRefreshPrices({
    int waitSeconds = 3,
  }) async => loadPrices();

  // ─── CRUD no-op (로컬 state에서 처리됨) ───

  @override
  Future<void> addTransaction(Transaction tx) async {}

  @override
  Future<void> updateTransaction(Transaction tx) async {}

  @override
  Future<void> deleteTransaction(String id) async {}

  @override
  Future<void> addOtherAsset(OtherAsset asset) async {}

  @override
  Future<void> updateOtherAsset(OtherAsset asset) async {}

  @override
  Future<void> deleteOtherAsset(String id) async {}

  @override
  Future<void> addPriceRow(
    String ticker,
    String market,
    String currency,
  ) async {}

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<List<PortfolioSnapshot>> loadSnapshots() async {
    return [..._snapshots]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> upsertSnapshot(PortfolioSnapshot snapshot) async {
    final index = _snapshots.indexWhere((s) => s.date == snapshot.date);
    if (index >= 0) {
      _snapshots[index] = snapshot;
    } else {
      _snapshots.add(snapshot);
    }
  }

  @override
  Future<void> upsertSnapshots(List<PortfolioSnapshot> snapshots) async {
    for (final snapshot in snapshots) {
      await upsertSnapshot(snapshot);
    }
  }

  @override
  Future<BackfillPriceData> loadBackfillPriceData({
    required List<BackfillPriceRequest> requests,
    required DateTime start,
    required DateTime end,
    int waitSeconds = 20,
  }) async {
    final dates = <String>[];
    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      dates.add('$y-$m-$d');
    }

    final prices = <String, Map<String, double>>{};
    for (final request in requests) {
      final quote = MockData.quotes.firstWhere(
        (q) => q.ticker == request.ticker,
        orElse: () => StockQuote(
          ticker: request.ticker,
          name: request.ticker,
          price: 1,
          changePct: 0,
          closeYest: 1,
          currency: 'USD',
        ),
      );
      prices[request.ticker] = {for (final date in dates) date: quote.price};
    }

    return BackfillPriceData(
      pricesByTicker: prices,
      exchangeRates: {for (final date in dates) date: MockData.exchangeRate},
      failedSymbols: const [],
    );
  }

  @override
  Future<int> findRowById(String sheetName, String id) async => 0;
}
