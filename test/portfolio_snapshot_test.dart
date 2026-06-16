import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/portfolio_snapshot.dart';

void main() {
  test('PortfolioSnapshot sheet row round trip', () {
    const snapshot = PortfolioSnapshot(
      id: 'snapshot-2026-06-16',
      date: '2026-06-16',
      totalValueKRW: 150000000,
      totalCostKRW: 100000000,
      profitKRW: 50000000,
      profitPct: 50,
      dailyChangeKRW: 1200000,
      dailyChangePct: 0.8,
      exchangeRate: 1380,
      source: 'live',
      createdAt: '2026-06-16T12:00:00.000',
      schemaVersion: 1,
    );

    final parsed = PortfolioSnapshot.fromSheetRow(snapshot.toSheetRow());

    expect(parsed.id, snapshot.id);
    expect(parsed.date, snapshot.date);
    expect(parsed.totalValueKRW, snapshot.totalValueKRW);
    expect(parsed.totalCostKRW, snapshot.totalCostKRW);
    expect(parsed.profitKRW, snapshot.profitKRW);
    expect(parsed.profitPct, snapshot.profitPct);
    expect(parsed.dailyChangeKRW, snapshot.dailyChangeKRW);
    expect(parsed.dailyChangePct, snapshot.dailyChangePct);
    expect(parsed.exchangeRate, snapshot.exchangeRate);
    expect(parsed.source, snapshot.source);
    expect(parsed.createdAt, snapshot.createdAt);
    expect(parsed.schemaVersion, snapshot.schemaVersion);
  });
}
