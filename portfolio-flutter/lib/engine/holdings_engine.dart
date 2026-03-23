import '../models/transaction.dart';
import '../models/holding.dart';

List<Holding> replayTransactions(List<Transaction> transactions) {
  final sorted = List<Transaction>.from(transactions)
    ..sort((a, b) => a.date.compareTo(b.date));

  final map = <String, Holding>{};

  for (final tx in sorted) {
    final key = '${tx.account}::${tx.ticker}';
    final existing = map[key];

    switch (tx.type) {
      case TransactionType.buy:
      case TransactionType.openingBalance:
      case TransactionType.adjustment:
        if (existing != null) {
          final totalShares = existing.shares + tx.shares;
          existing.avgCost =
              (existing.shares * existing.avgCost + tx.shares * tx.price) / totalShares;
          existing.avgExchangeRate =
              (existing.shares * existing.avgExchangeRate + tx.shares * tx.exchangeRate) / totalShares;
          existing.shares = totalShares;
        } else {
          map[key] = Holding(
            account: tx.account, ticker: tx.ticker, market: tx.market,
            currency: tx.currency, shares: tx.shares, avgCost: tx.price,
            avgExchangeRate: tx.exchangeRate,
          );
        }
        break;
      case TransactionType.sell:
        if (existing != null) {
          existing.shares -= tx.shares;
          if (existing.shares <= 0) map.remove(key);
        }
        break;
    }
  }

  return map.values.toList();
}
