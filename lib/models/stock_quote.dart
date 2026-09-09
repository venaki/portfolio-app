import 'sheet_schema.dart';
import 'ticker_symbol.dart';

class StockQuote {
  final String ticker;
  final String name;
  final double price;
  final double changePct;
  final double closeYest;
  final String currency;
  final bool isStale;

  /// Time this quote was successfully received, not the exchange trade time.
  final DateTime? fetchedAt;

  const StockQuote({
    required this.ticker,
    required this.name,
    required this.price,
    required this.changePct,
    required this.closeYest,
    required this.currency,
    this.isStale = false,
    this.fetchedAt,
  });

  factory StockQuote.fromSheetRow(List<String> row) {
    final market = sheetCell(row, 1).trim().toUpperCase();
    final ticker = normalizeTicker(
      sheetCell(row, 0),
      isKorean: market == 'KRX' || market == 'KOSDAQ',
    );
    return StockQuote(
      ticker: ticker,
      name: sheetCell(row, 4),
      price: double.tryParse(sheetCell(row, 3)) ?? double.nan,
      changePct: double.tryParse(sheetCell(row, 5)) ?? double.nan,
      closeYest: double.tryParse(sheetCell(row, 6)) ?? double.nan,
      currency: sheetCell(row, 7, 'USD').trim().toUpperCase(),
    );
  }

  bool get hasValidPrice =>
      price.isFinite && price > 0 && (currency == 'USD' || currency == 'KRW');
  bool get hasPreviousClose => closeYest.isFinite && closeYest > 0;
  bool get hasError => !hasValidPrice;

  StockQuote copyWith({
    double? price,
    double? changePct,
    double? closeYest,
    bool? isStale,
    DateTime? fetchedAt,
  }) => StockQuote(
    ticker: ticker,
    name: name,
    currency: currency,
    price: price ?? this.price,
    changePct: changePct ?? this.changePct,
    closeYest: closeYest ?? this.closeYest,
    isStale: isStale ?? this.isStale,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
}
