import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/screens/history_screen.dart';
import 'package:portfolio_flutter/widgets/asset_form.dart';
import 'package:portfolio_flutter/widgets/transaction_form.dart';
import 'forms_test.dart' show connected, formApp;

void main() {
  testWidgets('compact forms retain validation and fit a mobile viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final asset in [true, false]) {
      final notifier = await connected();
      await tester.pumpWidget(
        formApp(
          notifier,
          asset
              ? AssetForm(asset: notifier.state.otherAssets.first)
              : TransactionForm(transaction: notifier.state.transactions.first),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, '삭제'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('history keeps its compact filter header at mobile width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = await connected();
    await tester.pumpWidget(formApp(notifier, const HistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('필터'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('필터'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('기간 선택'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
