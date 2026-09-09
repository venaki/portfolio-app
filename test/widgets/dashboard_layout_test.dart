import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/holding.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/stock_quote.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/screens/dashboard_screen.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';
import 'package:portfolio_flutter/widgets/account_card.dart';
import 'package:portfolio_flutter/widgets/total_asset_card.dart';
import 'package:portfolio_flutter/widgets/type_group_card.dart';

class _DashboardNotifier extends PortfolioNotifier {
  _DashboardNotifier(PortfolioState initial)
    : super(MockSheetsService(), enableTimer: false) {
    state = initial;
  }
}

PortfolioState portfolio({bool missingQuote = false}) => PortfolioState(
  holdings: [
    Holding(
      account: 'A',
      ticker: 'XYZ',
      market: Market.us,
      currency: Currency.usd,
      shares: 2,
      avgCost: 150,
      avgExchangeRate: 1500,
      avgCostKRW: 250000,
    ),
    Holding(
      account: 'B',
      ticker: 'XYZ',
      market: Market.us,
      currency: Currency.usd,
      shares: 1,
      avgCost: 100,
      avgExchangeRate: 1000,
      avgCostKRW: 100000,
    ),
  ],
  quotes: missingQuote
      ? {}
      : const {
          'XYZ': StockQuote(
            ticker: 'XYZ',
            name: 'Example',
            price: 250,
            closeYest: 240,
            changePct: 4.16,
            currency: 'USD',
          ),
        },
  otherAssets: const [
    OtherAsset(
      id: 'debt',
      account: 'A',
      name: '대출',
      category: AssetCategory.loan,
      value: 100000,
      currency: Currency.krw,
      date: '2026-01-01',
    ),
  ],
  settings: const AppSettings(accounts: ['A', 'B']),
  exchangeRate: 1500,
  lastUpdated: DateTime(2026, 1, 10, 12, 34),
);

Future<void> showDashboard(
  WidgetTester tester,
  PortfolioState state, {
  double width = 1440,
  String tab = '현황',
  String mode = 'By Account',
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        portfolioProvider.overrideWith((ref) => _DashboardNotifier(state)),
        dashboardAnalysisTabProvider.overrideWith((ref) => tab),
        dashboardViewModeProvider.overrideWith((ref) => mode),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6E6E)),
        ),
        home: const Scaffold(body: DashboardScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overview preserves original cards, spacing and exact KRW cost', (
    tester,
  ) async {
    await showDashboard(tester, portfolio());
    final total = tester.widget<TotalAssetCard>(find.byType(TotalAssetCard));
    expect(total.totalCostKRW, 500000);
    expect(total.totalValueKRW, 1025000);
    expect(total.dailyChangePct, closeTo(45000 / 980000 * 100, 0.000001));
    expect(find.text('TOTAL ASSETS'), findsOneWidget);
    expect(find.text('총 순자산'), findsNothing);
    expect(tester.getTopLeft(find.byType(TotalAssetCard)).dx, 40);
    final first = tester.getRect(find.byType(AccountCard).at(0));
    final second = tester.getRect(find.byType(AccountCard).at(1));
    expect(second.top, first.top);
    expect(second.left - first.right, 8);
    final label = tester.widget<Text>(find.text('TOTAL ASSETS'));
    expect(label.style!.fontSize, 11);
    expect(label.style!.letterSpacing, 2);
    expect(find.text('원금'), findsNothing);
    await tester.tap(find.text('펼치기'));
    await tester.pumpAndSettle();
    expect(find.text('원금'), findsWidgets);
    expect(find.text('접기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile account cards stack with original eight pixel gap', (
    tester,
  ) async {
    await showDashboard(tester, portfolio(), width: 600);
    expect(tester.getTopLeft(find.byType(TotalAssetCard)).dx, 24);
    final first = tester.getRect(find.byType(AccountCard).at(0));
    final second = tester.getRect(find.byType(AccountCard).at(1));
    expect(second.left, first.left);
    expect(second.top - first.bottom, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'type cards aggregate positions while retaining missing price protection',
    (tester) async {
      await showDashboard(
        tester,
        portfolio(missingQuote: true),
        mode: 'By Type',
      );
      final group = tester.widget<TypeGroupCard>(
        find.byType(TypeGroupCard).first,
      );
      expect(group.title, '미국주식');
      expect(group.items, hasLength(1));
      expect(group.items.single.shares, 3);
      expect(group.items.single.costKRW, 600000);
      expect(group.items.single.hasPrice, isFalse);
      expect(group.items.single.isComplete, isFalse);
      expect(find.text('미평가'), findsOneWidget);
      expect(find.text('오늘 · 시세 확인 필요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'allocation restores summary, selected percentage and original donut',
    (tester) async {
      await showDashboard(tester, portfolio(), tab: '비중');
      expect(find.text('자산 합계'), findsOneWidget);
      expect(find.text('순자산'), findsOneWidget);
      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.centerSpaceRadius, 82);
      expect(chart.data.startDegreeOffset, -90);
      expect(chart.data.sections.single.radius, 48);
      expect(chart.data.sections.single.value, 1125000);
      expect(tester.getSize(find.byType(PieChart)), const Size(320, 320));
      expect(find.text('100.0%'), findsWidgets);
      expect(find.text('비중은 부채를 제외한 자산 합계 기준입니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
