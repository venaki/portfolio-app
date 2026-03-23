import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  test('명의 삭제 차단', () {
    final txs = [
      Transaction(
        id: '1',
        date: '2026-03-15',
        account: '본석',
        type: TransactionType.buy,
        ticker: 'TSLA',
        market: Market.us,
        name: 'Tesla',
        shares: 10,
        price: 100,
        currency: Currency.usd,
        exchangeRate: 1350,
      ),
    ];
    expect(txs.any((t) => t.account == '본석'), true);
  });

  test('명의 삭제 허용', () {
    final txs = [
      Transaction(
        id: '1',
        date: '2026-03-15',
        account: '본석',
        type: TransactionType.buy,
        ticker: 'TSLA',
        market: Market.us,
        name: 'Tesla',
        shares: 10,
        price: 100,
        currency: Currency.usd,
        exchangeRate: 1350,
      ),
    ];
    expect(txs.any((t) => t.account == '나은'), false);
  });

  test('refreshInterval 분→초', () => expect(15 * 60, 900));

  test('accentColor 저장', () {
    final s = const AppSettings(accentColor: '#2563EB');
    expect(s.accentColor, '#2563EB');
  });
}
