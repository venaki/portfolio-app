import 'transaction.dart';

class Holding {
  final String account;
  final String ticker;
  final Market market;
  final Currency currency;
  double shares;
  double avgCost;
  double avgExchangeRate;

  Holding({
    required this.account, required this.ticker, required this.market,
    required this.currency, required this.shares, required this.avgCost,
    required this.avgExchangeRate,
  });
}
