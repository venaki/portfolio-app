import '../models/app_settings.dart';
import '../models/holding.dart';
import '../models/other_asset.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import '../models/sheet_schema.dart';

const _unchanged = Object();

class PortfolioState {
  final List<Transaction> transactions;
  final List<Holding> holdings;
  final Map<String, StockQuote> quotes;
  final double exchangeRate;
  final List<OtherAsset> otherAssets;
  final List<PortfolioSnapshot> snapshots;
  final AppSettings settings;
  final bool isLoading, isSaving, isBackfilling;
  final String? spreadsheetId,
      spreadsheetName,
      backfillMessage,
      error,
      historyDirtyFrom;
  final List<String> dataIssues, staleTickers;
  final DateTime? lastUpdated;
  final String? asOfDate;
  const PortfolioState({
    this.transactions = const [],
    this.holdings = const [],
    this.quotes = const {},
    this.exchangeRate = 0,
    this.otherAssets = const [],
    this.snapshots = const [],
    this.settings = const AppSettings(),
    this.isLoading = false,
    this.isSaving = false,
    this.isBackfilling = false,
    this.spreadsheetId,
    this.spreadsheetName,
    this.backfillMessage,
    this.error,
    this.historyDirtyFrom,
    this.dataIssues = const [],
    this.staleTickers = const [],
    this.lastUpdated,
    this.asOfDate,
  });
  List<ConsolidatedAsset> get consolidatedOtherAssets => consolidateOtherAssets(
    otherAssets
        .where(
          (asset) =>
              asset.date.compareTo(asOfDate ?? dateKey(DateTime.now())) <= 0,
        )
        .toList(),
  );
  bool get canWrite =>
      spreadsheetId != null &&
      dataIssues.isEmpty &&
      !isLoading &&
      !isSaving &&
      !isBackfilling;
  PortfolioState copyWith({
    List<Transaction>? transactions,
    List<Holding>? holdings,
    Map<String, StockQuote>? quotes,
    double? exchangeRate,
    List<OtherAsset>? otherAssets,
    List<PortfolioSnapshot>? snapshots,
    AppSettings? settings,
    bool? isLoading,
    bool? isSaving,
    bool? isBackfilling,
    Object? spreadsheetId = _unchanged,
    Object? spreadsheetName = _unchanged,
    Object? backfillMessage = _unchanged,
    Object? error = _unchanged,
    Object? historyDirtyFrom = _unchanged,
    List<String>? dataIssues,
    List<String>? staleTickers,
    Object? lastUpdated = _unchanged,
    String? asOfDate,
  }) => PortfolioState(
    transactions: transactions ?? this.transactions,
    holdings: holdings ?? this.holdings,
    quotes: quotes ?? this.quotes,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    otherAssets: otherAssets ?? this.otherAssets,
    snapshots: snapshots ?? this.snapshots,
    settings: settings ?? this.settings,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isBackfilling: isBackfilling ?? this.isBackfilling,
    spreadsheetId: identical(spreadsheetId, _unchanged)
        ? this.spreadsheetId
        : spreadsheetId as String?,
    spreadsheetName: identical(spreadsheetName, _unchanged)
        ? this.spreadsheetName
        : spreadsheetName as String?,
    backfillMessage: identical(backfillMessage, _unchanged)
        ? this.backfillMessage
        : backfillMessage as String?,
    error: identical(error, _unchanged) ? this.error : error as String?,
    historyDirtyFrom: identical(historyDirtyFrom, _unchanged)
        ? this.historyDirtyFrom
        : historyDirtyFrom as String?,
    dataIssues: dataIssues ?? this.dataIssues,
    staleTickers: staleTickers ?? this.staleTickers,
    lastUpdated: identical(lastUpdated, _unchanged)
        ? this.lastUpdated
        : lastUpdated as DateTime?,
    asOfDate: asOfDate ?? this.asOfDate,
  );
}
