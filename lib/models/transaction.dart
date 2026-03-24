enum TransactionType { buy, sell, openingBalance, adjustment }

enum Market { us, krx, kosdaq }

enum Currency { usd, krw }

class Transaction {
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

  const Transaction({
    required this.id, required this.date, required this.account,
    required this.type, required this.ticker, required this.market,
    required this.name, required this.shares, required this.price,
    required this.currency, required this.exchangeRate, this.broker = '',
    this.memo = '',
  });

  factory Transaction.fromSheetRow(List<String> row) {
    return Transaction(
      id: row[0], date: row[1], account: row[2],
      type: _parseType(row[3]), ticker: row[4], market: _parseMarket(row[5]),
      name: row[6], shares: double.tryParse(row[7]) ?? 0,
      price: double.tryParse(row[8]) ?? 0,
      currency: row[9] == 'KRW' ? Currency.krw : Currency.usd,
      exchangeRate: double.tryParse(row[10]) ?? 0,
      memo: row.length > 11 ? row[11] : '',
      broker: row.length > 12 ? row[12] : '',
    );
  }

  List<String> toSheetRow() {
    return [id, date, account, type.toSheetValue(), ticker, market.toSheetValue(),
            name, shares.toString(), price.toString(),
            currency == Currency.krw ? 'KRW' : 'USD', exchangeRate.toString(), memo, broker];
  }

  static TransactionType _parseType(String value) {
    switch (value) {
      case 'buy': return TransactionType.buy;
      case 'sell': return TransactionType.sell;
      case 'opening_balance': return TransactionType.openingBalance;
      case 'adjustment': return TransactionType.adjustment;
      default: return TransactionType.buy;
    }
  }

  static Market _parseMarket(String value) {
    switch (value) {
      case 'KRX': return Market.krx;
      case 'KOSDAQ': return Market.kosdaq;
      default: return Market.us;
    }
  }
}

extension TransactionTypeExt on TransactionType {
  String toSheetValue() {
    switch (this) {
      case TransactionType.buy: return 'buy';
      case TransactionType.sell: return 'sell';
      case TransactionType.openingBalance: return 'opening_balance';
      case TransactionType.adjustment: return 'adjustment';
    }
  }
}

extension MarketExt on Market {
  String toSheetValue() {
    switch (this) {
      case Market.us: return 'US';
      case Market.krx: return 'KRX';
      case Market.kosdaq: return 'KOSDAQ';
    }
  }
}
