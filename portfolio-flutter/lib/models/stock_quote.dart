class StockQuote {
  final String ticker;
  final String name;
  final double price;
  final double changePct;
  final double closeYest;
  final String currency;

  const StockQuote({
    required this.ticker, required this.name, required this.price,
    required this.changePct, required this.closeYest, required this.currency,
  });

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
