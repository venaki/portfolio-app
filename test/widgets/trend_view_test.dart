import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/portfolio_snapshot.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/screens/dashboard/trend_view.dart';

PortfolioSnapshot snapshot(String date, double value) => PortfolioSnapshot(
  id: date,
  date: date,
  totalValueKRW: value,
  totalCostKRW: -25000,
  profitKRW: value + 25000,
  profitPct: 0,
  dailyChangeKRW: 0,
  dailyChangePct: 0,
  exchangeRate: 1300,
  source: 'test',
  createdAt: '${date}T12:00:00Z',
);

void main() {
  testWidgets(
    'negative net assets render with real date spacing and comparison',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = PortfolioState(
        snapshots: [
          snapshot('2026-01-01', -30000),
          snapshot('2026-01-02', -20000),
          snapshot('2026-01-11', -10000),
        ],
        historyDirtyFrom: '2026-01-01',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dashboardTrendRangeProvider.overrideWith((ref) => '전체')],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardTrendView(portfolio: state),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.map((spot) => spot.x), [
        0,
        1,
        10,
      ]);
      expect(chart.data.minY, lessThanOrEqualTo(-30000));
      expect(chart.data.maxY, greaterThanOrEqualTo(-10000));
      expect(chart.data.gridData.horizontalInterval, greaterThan(0));
      expect(
        find.textContaining('2026-01-01 대비', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('이전 순자산 기록'), findsOneWidget);
      expect(find.text('투자 자산'), findsOneWidget);
      expect(find.text('스냅샷 기록 / 복원'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.getSize(find.byType(LineChart)).height, 260);
      expect(chart.data.lineBarsData.first.barWidth, 2.5);
      expect(tester.takeException(), isNull);
    },
  );
}
