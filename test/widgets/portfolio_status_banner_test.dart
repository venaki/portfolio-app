import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';
import 'package:portfolio_flutter/widgets/portfolio_status_banner.dart';

class _StatusNotifier extends PortfolioNotifier {
  _StatusNotifier(PortfolioState initial)
    : super(MockSheetsService(), enableTimer: false) {
    state = initial;
  }
}

void main() {
  testWidgets(
    'compact data notice retains every row detail and write protection',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final issues = [
        for (var i = 0; i < 6; i++) 'Transactions ${71 + i}행: 오류 $i',
      ];
      final notifier = _StatusNotifier(
        PortfolioState(spreadsheetId: 'test-sheet', dataIssues: issues),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [portfolioProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(
            home: Scaffold(body: Column(children: [PortfolioStatusBanner()])),
          ),
        ),
      );
      expect(notifier.state.canWrite, isFalse);
      expect(find.text('데이터 확인이 필요합니다 · 6건'), findsOneWidget);
      expect(find.textContaining('Transactions'), findsNothing);
      expect(
        tester.getSize(find.byType(PortfolioStatusBanner)).height,
        lessThan(140),
      );
      await tester.tap(find.text('상세 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        issues.join('\n\n'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
