import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/engine/calculations.dart';
import 'package:portfolio_flutter/models/holding.dart';
import 'package:portfolio_flutter/models/transaction.dart';

void main() {
  final usdHolding = Holding(
    account: '본석', ticker: 'TSLA', market: Market.us,
    currency: Currency.usd, shares: 10, avgCost: 300, avgExchangeRate: 1400,
  );

  final krwHolding = Holding(
    account: '본석', ticker: '005930', market: Market.krx,
    currency: Currency.krw, shares: 100, avgCost: 70000, avgExchangeRate: 0,
  );

  group('calcProfitUSD', () {
    test('positive profit', () => expect(calcProfitUSD(usdHolding, 350), 500));
    test('negative profit', () => expect(calcProfitUSD(usdHolding, 250), -500));
  });

  group('calcProfitPercentUSD', () {
    test('positive', () => expect(calcProfitPercentUSD(usdHolding, 350), closeTo(16.67, 0.01)));
    test('zero avgCost returns 0', () {
      final h = Holding(account: 'x', ticker: 'X', market: Market.us,
        currency: Currency.usd, shares: 10, avgCost: 0, avgExchangeRate: 0);
      expect(calcProfitPercentUSD(h, 100), 0);
    });
  });

  group('calcTotalValueKRW', () {
    test('USD holding', () => expect(calcTotalValueKRW(usdHolding, 350, 1500), 5250000));
    test('KRW holding', () => expect(calcTotalValueKRW(krwHolding, 80000, 1500), 8000000));
  });

  group('calcCostKRW', () {
    test('USD holding', () => expect(calcCostKRW(usdHolding), 4200000));
    test('KRW holding', () => expect(calcCostKRW(krwHolding), 7000000));
  });

  group('calcProfitKRW', () {
    test('positive', () => expect(calcProfitKRW(usdHolding, 350, 1500), 1050000));
  });

  group('calcProfitPercentKRW', () {
    test('positive', () => expect(calcProfitPercentKRW(usdHolding, 350, 1500), 25.0));
    test('zero cost returns 0', () {
      final h = Holding(account: 'x', ticker: 'X', market: Market.us,
        currency: Currency.usd, shares: 0, avgCost: 0, avgExchangeRate: 0);
      expect(calcProfitPercentKRW(h, 100, 1500), 0);
    });
  });

  group('calcDailyChangeKRW', () {
    test('USD holding', () => expect(calcDailyChangeKRW(usdHolding, 350, 340, 1500), 150000));
    test('KRW holding', () => expect(calcDailyChangeKRW(krwHolding, 80000, 78000, 1500), 200000));
  });

  group('calcRealizedPL', () {
    test('profit on sell', () {
      final r = calcRealizedPL(5, 400, 1500, 300, 1400);
      expect(r.usd, 500);
      expect(r.krw, 900000);
    });
  });
}
