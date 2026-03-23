import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/engine/holdings_engine.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  group('replayTransactions', () {
    test('single buy creates holding', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 10);
      expect(holdings[0].avgCost, 300);
      expect(holdings[0].avgExchangeRate, 1400);
    });

    test('two buys calculates weighted average', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
        Transaction(id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd, exchangeRate: 1500),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 20);
      expect(holdings[0].avgCost, 350);
      expect(holdings[0].avgExchangeRate, 1450);
    });

    test('sell reduces shares', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
        Transaction(id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 400, currency: Currency.usd, exchangeRate: 1500),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 5);
      expect(holdings[0].avgCost, 300);
    });

    test('sell all removes holding', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
        Transaction(id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd, exchangeRate: 1500),
      ];
      expect(replayTransactions(txs).length, 0);
    });

    test('different accounts are separate', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
        Transaction(id: '2', date: '2025-01-01', account: '연지',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 350, currency: Currency.usd, exchangeRate: 1450),
      ];
      expect(replayTransactions(txs).length, 2);
    });

    test('opening_balance works like buy', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.openingBalance, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 300, currency: Currency.usd, exchangeRate: 1400),
      ];
      final holdings = replayTransactions(txs);
      expect(holdings.length, 1);
      expect(holdings[0].shares, 10);
    });

    test('oversell removes holding', () {
      final txs = [
        Transaction(id: '1', date: '2025-01-01', account: '본석',
          type: TransactionType.buy, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 5, price: 300, currency: Currency.usd, exchangeRate: 1400),
        Transaction(id: '2', date: '2025-01-02', account: '본석',
          type: TransactionType.sell, ticker: 'TSLA', market: Market.us,
          name: 'Tesla', shares: 10, price: 400, currency: Currency.usd, exchangeRate: 1500),
      ];
      expect(replayTransactions(txs).length, 0);
    });
  });
}
