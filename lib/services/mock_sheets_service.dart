import '../models/transaction.dart';
import '../models/stock_quote.dart';
import '../models/other_asset.dart';
import '../models/app_settings.dart';
import 'sheets_service.dart';
import 'mock_data.dart';

/// Dev 모드용 MockSheetsService — API 호출 없이 로컬 메모리로 동작
class MockSheetsService extends SheetsService {
  MockSheetsService() : super(getAuthHeaders: () async => {});

  @override
  Future<String> createSpreadsheet() async => 'mock-spreadsheet-id';

  @override
  Future<({
    List<Transaction> transactions,
    List<StockQuote> quotes,
    double exchangeRate,
    List<OtherAsset> otherAssets,
    AppSettings settings,
  })> loadAll() async {
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
    return (
      quotes: MockData.quotes,
      exchangeRate: MockData.exchangeRate,
    );
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
  Future<void> addPriceRow(String ticker, String market, String currency) async {}

  @override
  Future<void> saveSettings(AppSettings settings) async {}

  @override
  Future<int> findRowById(String sheetName, String id) async => 0;
}
