import 'dart:math' as math;

import '../models/other_asset.dart';
import '../models/portfolio_snapshot.dart';
import '../models/sheet_schema.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import 'holdings_engine.dart';
import 'portfolio_valuation.dart';

PortfolioSnapshot? buildCurrentSnapshot({
  required PortfolioValuation valuation,
  required double exchangeRate,
  required DateTime now,
  String source = 'live',
}) {
  if (!valuation.isComplete ||
      !valuation.isDailyComplete ||
      !exchangeRate.isFinite ||
      exchangeRate <= 0) {
    return null;
  }
  final total = valuation.total;
  final key = dateKey(now);
  final snapshot = PortfolioSnapshot(
    id: 'snapshot-$key',
    date: key,
    totalValueKRW: total.valueKRW,
    totalCostKRW: total.costKRW,
    profitKRW: total.profitKRW,
    profitPct: total.profitPct,
    dailyChangeKRW: total.dailyChangeKRW,
    dailyChangePct: total.dailyChangePct,
    exchangeRate: exchangeRate,
    source: source,
    createdAt: now.toIso8601String(),
  );
  return snapshot.validationErrors.isEmpty ? snapshot : null;
}

/// Search all supplied history, including observations before the query range.
/// A future observation is never used to value an earlier date.
double? historicalValueOnOrBefore(
  Map<String, double> series,
  DateTime date, {
  int maxAgeDays = 7,
}) {
  final key = dateKey(date);
  final earliest = dateKey(date.subtract(Duration(days: maxAgeDays)));
  String? found;
  for (final entry in series.entries) {
    if (!entry.value.isFinite || entry.value <= 0 || !isValidDate(entry.key)) {
      continue;
    }
    if (entry.key.compareTo(key) > 0 || entry.key.compareTo(earliest) < 0) {
      continue;
    }
    if (found == null || entry.key.compareTo(found) > 0) found = entry.key;
  }
  return found == null ? null : series[found];
}

class SnapshotBuildResult {
  final List<PortfolioSnapshot> snapshots;
  final List<String> issues;

  const SnapshotBuildResult({required this.snapshots, required this.issues});
  bool get isComplete => issues.isEmpty;
}

SnapshotBuildResult buildHistoricalSnapshots({
  required List<Transaction> transactions,
  required List<OtherAsset> otherAssets,
  required Map<String, Map<String, double>> pricesByTicker,
  required Map<String, double> exchangeRates,
  required DateTime start,
  required DateTime end,
  DateTime? createdAt,
}) {
  final snapshots = <PortfolioSnapshot>[];
  final issues = <String>[];
  final first = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  if (last.isBefore(first)) {
    return const SnapshotBuildResult(
      snapshots: [],
      issues: ['복원할 과거 기간이 없습니다.'],
    );
  }
  final timestamp = (createdAt ?? DateTime.now()).toIso8601String();
  for (
    var date = first;
    !date.isAfter(last);
    date = DateTime(date.year, date.month, date.day + 1)
  ) {
    final key = dateKey(date);
    final ledger = replayPortfolio(transactions, throughDate: key);
    final entries = otherAssets
        .where((a) => a.date.compareTo(key) <= 0)
        .toList();
    final assetIssues = validateOtherAssetLedger(entries);
    if (!ledger.isValid || assetIssues.isNotEmpty) {
      issues.add('$key: 거래 내역 오류로 스냅샷을 생성하지 않았습니다.');
      continue;
    }
    final assets = consolidateOtherAssets(entries);
    final requiresFX =
        ledger.holdings.any((h) => h.currency == Currency.usd) ||
        assets.any((a) => a.currency == Currency.usd);
    final historicalRate = historicalValueOnOrBefore(exchangeRates, date);
    if (requiresFX && historicalRate == null) {
      issues.add('$key: 과거 환율이 없어 스냅샷을 생성하지 않았습니다.');
      continue;
    }
    final rate = historicalRate ?? 1.0;
    final quotes = <String, StockQuote>{};
    for (final holding in ledger.holdings) {
      final series = pricesByTicker[holding.ticker] ?? const <String, double>{};
      final price = historicalValueOnOrBefore(series, date);
      final previous = historicalValueOnOrBefore(
        series,
        DateTime(date.year, date.month, date.day - 1),
      );
      quotes[holding.ticker] = StockQuote(
        ticker: holding.ticker,
        name: holding.ticker,
        price: price ?? double.nan,
        closeYest: previous ?? double.nan,
        changePct: price != null && previous != null
            ? (price / previous - 1) * 100
            : double.nan,
        currency: holding.currency == Currency.usd ? 'USD' : 'KRW',
      );
    }
    final valuation = evaluatePortfolio(
      holdings: ledger.holdings,
      otherAssets: assets,
      quotes: quotes,
      exchangeRate: rate,
    );
    final snapshot = buildCurrentSnapshot(
      valuation: valuation,
      exchangeRate: rate,
      now: date,
      source: 'backfill',
    );
    if (snapshot == null) {
      issues.add('$key: ${valuation.issues.join(' ')}');
      continue;
    }
    snapshots.add(
      PortfolioSnapshot(
        id: snapshot.id,
        date: snapshot.date,
        totalValueKRW: snapshot.totalValueKRW,
        totalCostKRW: snapshot.totalCostKRW,
        profitKRW: snapshot.profitKRW,
        profitPct: snapshot.profitPct,
        dailyChangeKRW: snapshot.dailyChangeKRW,
        dailyChangePct: snapshot.dailyChangePct,
        exchangeRate: snapshot.exchangeRate,
        source: snapshot.source,
        createdAt: timestamp,
      ),
    );
  }
  return SnapshotBuildResult(
    snapshots: List.unmodifiable(snapshots),
    issues: List.unmodifiable(issues),
  );
}

List<PortfolioSnapshot> filterSnapshotRange(
  List<PortfolioSnapshot> snapshots,
  String range, {
  DateTime? anchor,
}) {
  final sorted = snapshots.where((s) => isValidDate(s.date)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (sorted.isEmpty || range == '전체') return sorted;
  final latest = anchor ?? DateTime.parse(sorted.last.date);
  final start = switch (range) {
    '올해' => DateTime(latest.year, 1, 1),
    '1개월' => latest.subtract(const Duration(days: 30)),
    '3개월' => latest.subtract(const Duration(days: 90)),
    '6개월' => latest.subtract(const Duration(days: 180)),
    _ => latest.subtract(const Duration(days: 365)),
  };
  final firstKey = dateKey(start);
  final lastKey = dateKey(latest);
  return sorted
      .where(
        (s) =>
            s.date.compareTo(firstKey) >= 0 && s.date.compareTo(lastKey) <= 0,
      )
      .toList();
}

double snapshotXAxis(DateTime date, DateTime origin) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(origin.year, origin.month, origin.day))
        .inDays
        .toDouble();

String snapshotComparisonLabel(List<PortfolioSnapshot> snapshots) {
  final sorted = filterSnapshotRange(snapshots, '전체');
  return sorted.length < 2 ? '비교 기록 부족' : '${sorted.first.date} 대비';
}

/// A bounded number of ticks for negative, positive and flat portfolios alike.
double trendAxisInterval(Iterable<double> values, {int targetTicks = 4}) {
  final finite = values.where((v) => v.isFinite).toList();
  if (finite.isEmpty) return 1;
  final minValue = finite.reduce(math.min);
  final maxValue = finite.reduce(math.max);
  var span = maxValue - minValue;
  if (!span.isFinite) span = math.max(minValue.abs(), maxValue.abs());
  if (span == 0) span = math.max(maxValue.abs() * 0.2, 1.0);
  final raw = span / math.max(targetTicks, 1);
  if (!raw.isFinite || raw <= 0) return span > 0 ? span : 1;
  final scale = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  if (!scale.isFinite || scale <= 0) return raw;
  final normalized = raw / scale;
  final step = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  final result = step * scale;
  return result.isFinite && result > 0 ? result : span;
}
