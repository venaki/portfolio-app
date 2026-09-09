import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';
import 'package:portfolio_flutter/widgets/asset_form.dart';
import 'package:portfolio_flutter/widgets/transaction_form.dart';

Future<PortfolioNotifier> connected() async {
  final notifier = PortfolioNotifier(MockSheetsService(), enableTimer: false);
  await notifier.connect('form-test');
  return notifier;
}

Widget formApp(PortfolioNotifier notifier, Widget form) => ProviderScope(
  overrides: [portfolioProvider.overrideWith((ref) => notifier)],
  child: MaterialApp(home: Scaffold(body: form)),
);
void main() {
  testWidgets('asset form blocks NaN before touching the ledger', (
    tester,
  ) async {
    final notifier = await connected();
    final count = notifier.state.otherAssets.length;
    await tester.pumpWidget(formApp(notifier, const AssetForm()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '테스트 예금');
    await tester.enterText(find.byType(TextFormField).at(1), 'NaN');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '추가'));
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();
    expect(find.text('올바른 숫자를 입력해주세요'), findsOneWidget);
    expect(notifier.state.otherAssets.length, count);
    expect(tester.takeException(), isNull);
  });
  testWidgets('US transaction requires historical exchange rate', (
    tester,
  ) async {
    final notifier = await connected();
    final tx = notifier.state.transactions.firstWhere(
      (tx) => tx.currency.name == 'usd',
    );
    await tester.pumpWidget(
      formApp(notifier, TransactionForm(transaction: tx)),
    );
    await tester.pumpAndSettle();
    // Ticker, shares, price, exchange rate, date, time, memo.
    await tester.enterText(find.byType(TextFormField).at(3), '');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '저장'));
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(find.text('금액을 입력해주세요'), findsOneWidget);
    expect(
      notifier.state.transactions
          .firstWhere((value) => value.id == tx.id)
          .exchangeRate,
      tx.exchangeRate,
    );
  });
  testWidgets(
    'asset delete requires confirmation and cancellation preserves data',
    (tester) async {
      final notifier = await connected();
      final asset = notifier.state.otherAssets.first;
      await tester.pumpWidget(formApp(notifier, AssetForm(asset: asset)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      expect(find.text('삭제한 내역은 자동으로 복구되지 않습니다. 삭제하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(
        notifier.state.otherAssets.any((value) => value.id == asset.id),
        isTrue,
      );
    },
  );
}
