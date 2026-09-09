import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/app.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';
import 'package:portfolio_flutter/widgets/custom_tab_bar.dart';

void main() {
  testWidgets(
    'leaving order editing restores portfolio and mobile navigation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final notifier = PortfolioNotifier(
        MockSheetsService(),
        enableTimer: false,
      );
      await notifier.connect('test-sheet');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portfolioProvider.overrideWith((ref) => notifier),
            spreadsheetIdProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: MainApp()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('포트폴리오'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('순서 편집')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('순서 편집'));
      await tester.pumpAndSettle();
      expect(find.text('취소'), findsOneWidget);
      await tester.tap(find.text('대시보드'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('포트폴리오'));
      await tester.pumpAndSettle();
      expect(find.text('취소'), findsNothing);
      expect(find.text('순서 편집'), findsOneWidget);
      await tester.tap(find.text('대시보드'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(CustomTabBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
