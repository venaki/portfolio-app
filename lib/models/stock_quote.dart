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
    final market = row.length > 1 ? row[1] : '';
    var ticker = row[0];
    // 한국 종목코드: 6자리로 정규화 (Sheets가 숫자로 해석해 앞자리 0 제거하는 문제 대응)
    if ((market == 'KRX' || market == 'KOSDAQ') && RegExp(r'^\d+$').hasMatch(ticker) && ticker.length < 6) {
      ticker = ticker.padLeft(6, '0');
    }
    return StockQuote(
      ticker: ticker,
      name: row.length > 4 ? row[4] : '',
      price: double.tryParse(row[3]) ?? 0,
      changePct: double.tryParse(row[5]) ?? 0,
      closeYest: double.tryParse(row[6]) ?? 0,
      currency: row.length > 7 ? row[7] : 'USD',
    );
  }

  bool get hasError => price == 0;
}
