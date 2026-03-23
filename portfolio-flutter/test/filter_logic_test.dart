import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/transaction.dart';

Transaction _tx({
  String account = '본석',
  Market market = Market.us,
  TransactionType type = TransactionType.buy,
  String ticker = 'TSLA',
}) =>
    Transaction(
      id: '${ticker}_$account',
      date: '2026-03-15',
      account: account,
      type: type,
      ticker: ticker,
      market: market,
      name: ticker,
      shares: 10,
      price: 100,
      currency: Currency.usd,
      exchangeRate: 1350,
    );

List<Transaction> applyFilters(
  List<Transaction> txs,
  String marketFilter,
  String accountFilter,
  String typeFilter,
) {
  return txs.where((tx) {
    if (marketFilter == '미국' && tx.market != Market.us) return false;
    if (marketFilter == '한국' &&
        tx.market != Market.krx &&
        tx.market != Market.kosdaq) return false;
    if (accountFilter != '전체' && tx.account != accountFilter) return false;
    if (typeFilter == '매수' && tx.type == TransactionType.sell) return false;
    if (typeFilter == '매도' && tx.type != TransactionType.sell) return false;
    return true;
  }).toList();
}

void main() {
  final transactions = [
    _tx(account: '본석', market: Market.us, type: TransactionType.buy),
    _tx(
        account: '연지',
        market: Market.krx,
        type: TransactionType.sell,
        ticker: '005930'),
    _tx(
        account: '본석',
        market: Market.kosdaq,
        type: TransactionType.buy,
        ticker: '000000'),
  ];

  test('전체 필터 - 모든 거래', () {
    expect(applyFilters(transactions, '전체', '전체', '전체').length, 3);
  });

  test('미국 필터', () {
    final r = applyFilters(transactions, '미국', '전체', '전체');
    expect(r.length, 1);
    expect(r.first.market, Market.us);
  });

  test('한국 필터 - KRX + KOSDAQ', () {
    expect(applyFilters(transactions, '한국', '전체', '전체').length, 2);
  });

  test('명의 필터', () {
    expect(applyFilters(transactions, '전체', '연지', '전체').length, 1);
  });

  test('매수 필터', () {
    expect(applyFilters(transactions, '전체', '전체', '매수').length, 2);
  });

  test('복합 필터', () {
    expect(applyFilters(transactions, '한국', '본석', '전체').length, 1);
  });
}
