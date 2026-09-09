import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/screens/portfolio_filters.dart';

Transaction transaction(
  String id,
  TransactionType type, {
  String broker = 'A',
  String date = '2026-01-02',
}) => Transaction(
  id: id,
  date: date,
  account: '계좌',
  type: type,
  ticker: 'AAPL',
  market: Market.us,
  name: 'Apple',
  shares: 1,
  price: 100,
  currency: Currency.usd,
  exchangeRate: 1300,
  broker: broker,
  memo: '장기 보유',
);
void main() {
  test(
    'production filter distinguishes buy from opening balance and adjustment',
    () {
      final values = [
        for (final type in TransactionType.values) transaction(type.name, type),
      ];
      expect(filterTransactions(values, type: '매수').map((tx) => tx.type), [
        TransactionType.buy,
      ]);
      expect(filterTransactions(values, type: '잔고 조정').length, 2);
    },
  );
  test(
    'production filter combines inclusive dates, broker and memo search',
    () {
      final values = [
        transaction('1', TransactionType.buy),
        transaction('2', TransactionType.sell, broker: 'B'),
        transaction('3', TransactionType.buy, date: '2026-01-01'),
      ];
      expect(
        filterTransactions(
          values,
          broker: 'A',
          query: '장기',
          from: DateTime(2026, 1, 2),
          to: DateTime(2026, 1, 2),
        ).map((tx) => tx.id),
        ['1'],
      );
    },
  );
  test('broker filter excludes unrelated other assets', () {
    final assets = [
      const OtherAsset(
        id: '1',
        account: '계좌',
        name: '예금',
        category: AssetCategory.savings,
        value: 100,
        currency: Currency.krw,
        date: '2026-01-02',
      ),
    ];
    expect(filterAssets(assets, broker: 'A'), isEmpty);
    expect(filterAssets(assets, query: '예금'), hasLength(1));
  });
  test('editing a subset preserves unfiltered order and adds new holdings', () {
    expect(
      mergeHoldingOrder(['A', 'B', 'C', 'D'], ['A', 'B', 'C', 'D', 'E'], [
        'D',
        'B',
      ]),
      ['A', 'D', 'C', 'B', 'E'],
    );
    expect(mergeHoldingOrder(['closed', 'A'], ['A', 'B'], ['B', 'A']), [
      'B',
      'A',
    ]);
  });
}
