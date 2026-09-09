import 'transaction.dart';

class Holding {
  final String account;
  final String broker;
  final String ticker;
  final Market market;
  final Currency currency;
  double shares;
  double avgCost;
  double avgExchangeRate;

  /// KRW unit cost is tracked independently of the native-currency unit cost.
  /// Multiplying separately averaged prices and FX rates loses cost basis.
  double avgCostKRW;

  Holding({
    required this.account,
    this.broker = '',
    required this.ticker,
    required this.market,
    required this.currency,
    required this.shares,
    required this.avgCost,
    required this.avgExchangeRate,
    double? avgCostKRW,
  }) : avgCostKRW =
           avgCostKRW ??
           avgCost * (currency == Currency.krw ? 1 : avgExchangeRate);

  double get costNative => shares * avgCost;
  double get costKRW => shares * avgCostKRW;
}
