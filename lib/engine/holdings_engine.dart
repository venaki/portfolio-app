import 'dart:math' as math;

import '../models/data_issue.dart';
import '../models/transaction.dart';
import '../models/holding.dart';

export '../models/data_issue.dart';

class RealizedTrade {
  final Transaction transaction;
  final double costNative;
  final double costKRW;
  final double proceedsNative;
  final double proceedsKRW;

  const RealizedTrade({
    required this.transaction,
    required this.costNative,
    required this.costKRW,
    required this.proceedsNative,
    required this.proceedsKRW,
  });

  double get profitNative => proceedsNative - costNative;
  double get profitKRW => proceedsKRW - costKRW;
  double get avgCost => costNative / transaction.shares;
  double get avgRate => costNative > 0 ? costKRW / costNative : 0;
}

class TransactionReplayResult {
  final List<Holding> holdings;
  final List<RealizedTrade> realizedTrades;
  final List<DataIssue> issues;

  const TransactionReplayResult({
    required this.holdings,
    required this.realizedTrades,
    required this.issues,
  });

  bool get isValid => issues.isEmpty;
}

/// Moving-average cost basis in each currency, using sheet order for ties.
/// Invalid legacy records are reported and skipped; callers must disclose issues
/// and block writes/snapshots until the source ledger has been repaired.
TransactionReplayResult replayPortfolio(
  List<Transaction> transactions, {
  String? throughDate,
}) {
  final sorted = transactions.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.sortKey.compareTo(b.$2.sortKey);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  final positions = <(String, String, String, Market, Currency), Holding>{};
  final seenIds = <String>{};
  final issues = <DataIssue>[];
  final realized = <RealizedTrade>[];

  for (final (_, tx) in sorted) {
    final errors = [...tx.validationErrors];
    if (!seenIds.add(tx.id)) errors.add('중복된 거래 ID입니다.');
    if (errors.isNotEmpty) {
      issues.add(DataIssue(recordId: tx.id, message: errors.join(' ')));
      continue;
    }
    if (throughDate != null && tx.date.compareTo(throughDate) > 0) continue;
    final key = (tx.account, tx.ticker, tx.broker, tx.market, tx.currency);
    final existing = positions[key];
    final rate = tx.currency == Currency.krw ? 1.0 : tx.exchangeRate;

    if (tx.type == TransactionType.sell) {
      final available = existing?.shares ?? 0.0;
      final tolerance = math.max(available, tx.shares) * 1e-10;
      if (existing == null || tx.shares - available > tolerance) {
        issues.add(
          DataIssue(
            recordId: tx.id,
            message: '매도 수량(${tx.shares})이 당시 보유 수량($available)을 초과합니다.',
          ),
        );
        continue;
      }
      final proceedsNative = tx.price * tx.shares;
      final proceedsKRW = proceedsNative * rate;
      if (!proceedsNative.isFinite || !proceedsKRW.isFinite) {
        issues.add(DataIssue(recordId: tx.id, message: '매도 금액이 계산 범위를 초과합니다.'));
        continue;
      }
      realized.add(
        RealizedTrade(
          transaction: tx,
          costNative: existing.avgCost * tx.shares,
          costKRW: existing.avgCostKRW * tx.shares,
          proceedsNative: proceedsNative,
          proceedsKRW: proceedsKRW,
        ),
      );
      existing.shares -= tx.shares;
      if (existing.shares.abs() <= tolerance) positions.remove(key);
      continue;
    }

    final quantity = (existing?.shares ?? 0) + tx.shares;
    final nativeCost = (existing?.costNative ?? 0) + tx.shares * tx.price;
    final krwCost = (existing?.costKRW ?? 0) + tx.shares * tx.price * rate;
    if (!quantity.isFinite || !nativeCost.isFinite || !krwCost.isFinite) {
      issues.add(DataIssue(recordId: tx.id, message: '거래 금액이 계산 범위를 초과합니다.'));
      continue;
    }
    positions[key] = Holding(
      account: tx.account,
      broker: tx.broker,
      ticker: tx.ticker,
      market: tx.market,
      currency: tx.currency,
      shares: quantity,
      avgCost: nativeCost / quantity,
      avgCostKRW: krwCost / quantity,
      avgExchangeRate: nativeCost > 0 ? krwCost / nativeCost : rate,
    );
  }
  return TransactionReplayResult(
    holdings: List.unmodifiable(positions.values),
    realizedTrades: List.unmodifiable(realized),
    issues: List.unmodifiable(issues),
  );
}

/// Compatibility API. New callers should consume diagnostics from replayPortfolio.
List<Holding> replayTransactions(List<Transaction> transactions) =>
    replayPortfolio(transactions).holdings;
