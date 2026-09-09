import 'sheet_schema.dart';

enum TransactionType { buy, sell, openingBalance, adjustment }

enum Market { us, krx, kosdaq }

enum Currency { usd, krw }

class Transaction {
  static const sheetHeaders = SheetSchema.transactions;
  final String id;
  final String date;
  final String account;
  final TransactionType type;
  final String ticker;
  final Market market;
  final String name;
  final double shares;
  final double price;
  final Currency currency;
  final double exchangeRate;
  final String broker;
  final String memo;
  final String time; // "HH:mm" format, e.g. "14:30"

  const Transaction({
    required this.id,
    required this.date,
    required this.account,
    required this.type,
    required this.ticker,
    required this.market,
    required this.name,
    required this.shares,
    required this.price,
    required this.currency,
    required this.exchangeRate,
    this.broker = '',
    this.memo = '',
    this.time = '00:00',
  });

  /// date + time 조합 정렬키 (e.g. "2024-03-15 14:30")
  String get sortKey => '$date $time';

  List<String> get validationErrors => [
    if (id.trim().isEmpty) '거래 ID가 없습니다.',
    if (account.trim().isEmpty) '계좌가 없습니다.',
    if (!isValidDate(date)) '날짜 형식이 올바르지 않습니다.',
    if (!isValidTime(time)) '시간 형식이 올바르지 않습니다.',
    if (ticker.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]*$').hasMatch(ticker))
      '종목코드가 올바르지 않습니다.',
    if (market != Market.us && !RegExp(r'^\d{6}$').hasMatch(ticker))
      '한국 종목코드는 6자리 숫자여야 합니다.',
    if (!shares.isFinite || shares <= 0) '수량은 0보다 큰 유한한 숫자여야 합니다.',
    if (!price.isFinite ||
        price < 0 ||
        ((type == TransactionType.buy || type == TransactionType.sell) &&
            price == 0))
      '거래 가격이 올바르지 않습니다.',
    if (currency == Currency.usd &&
        (!exchangeRate.isFinite || exchangeRate <= 0))
      '달러 거래에는 0보다 큰 환율이 필요합니다.',
    if ((market == Market.us) != (currency == Currency.usd))
      '시장과 거래 통화가 일치하지 않습니다.',
  ];

  factory Transaction.fromSheetRow(List<String> row) {
    final market = _parseMarket(sheetCell(row, 5));
    var ticker = sheetCell(row, 4).trim().toUpperCase();
    // 한국 종목코드: 6자리로 정규화 (Sheets가 숫자로 해석해 앞자리 0 제거하는 문제 대응)
    if ((market == Market.krx || market == Market.kosdaq) &&
        RegExp(r'^\d+$').hasMatch(ticker) &&
        ticker.length < 6) {
      ticker = ticker.padLeft(6, '0');
    }
    final currency = parseCurrency(sheetCell(row, 9));
    final rawTime = sheetCell(row, 13).trim();
    final transaction = Transaction(
      id: sheetCell(row, 0).trim(),
      date: sheetCell(row, 1).trim(),
      account: sheetCell(row, 2).trim(),
      type: _parseType(sheetCell(row, 3)),
      ticker: ticker,
      market: market,
      name: sheetCell(row, 6),
      shares: finiteSheetNumber(sheetCell(row, 7), '수량'),
      price: finiteSheetNumber(sheetCell(row, 8), '가격'),
      currency: currency,
      exchangeRate: currency == Currency.krw
          ? 1
          : finiteSheetNumber(sheetCell(row, 10), '환율'),
      memo: sheetCell(row, 11),
      broker: sheetCell(row, 12).trim(),
      time: rawTime.isEmpty ? '00:00' : rawTime,
    );
    requireValidRecord(transaction.validationErrors);
    return transaction;
  }

  List<String> toSheetRow() {
    return [
      id,
      date,
      account,
      type.toSheetValue(),
      ticker,
      market.toSheetValue(),
      name,
      shares.toString(),
      price.toString(),
      currency == Currency.krw ? 'KRW' : 'USD',
      exchangeRate.toString(),
      memo,
      broker,
      time,
    ];
  }

  static TransactionType _parseType(String value) {
    switch (value) {
      case 'buy':
        return TransactionType.buy;
      case 'sell':
        return TransactionType.sell;
      case 'opening_balance':
        return TransactionType.openingBalance;
      case 'adjustment':
        return TransactionType.adjustment;
      default:
        throw FormatException('알 수 없는 거래 유형: $value');
    }
  }

  static Market _parseMarket(String value) {
    switch (value) {
      case 'KRX':
        return Market.krx;
      case 'KOSDAQ':
        return Market.kosdaq;
      case 'US':
        return Market.us;
      default:
        throw FormatException('알 수 없는 시장: $value');
    }
  }
}

Currency parseCurrency(String value) => switch (value.trim().toUpperCase()) {
  'KRW' => Currency.krw,
  'USD' => Currency.usd,
  _ => throw FormatException('알 수 없는 통화: $value'),
};

extension TransactionTypeExt on TransactionType {
  String toSheetValue() {
    switch (this) {
      case TransactionType.buy:
        return 'buy';
      case TransactionType.sell:
        return 'sell';
      case TransactionType.openingBalance:
        return 'opening_balance';
      case TransactionType.adjustment:
        return 'adjustment';
    }
  }
}

extension MarketExt on Market {
  String toSheetValue() {
    switch (this) {
      case Market.us:
        return 'US';
      case Market.krx:
        return 'KRX';
      case Market.kosdaq:
        return 'KOSDAQ';
    }
  }
}
