import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/engine/calculations.dart';
import 'package:portfolio_flutter/engine/holdings_engine.dart';
import 'package:portfolio_flutter/engine/portfolio_valuation.dart';
import 'package:portfolio_flutter/engine/snapshot_engine.dart';
import 'package:portfolio_flutter/models/holding.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/stock_quote.dart';
import 'package:portfolio_flutter/models/transaction.dart';

Transaction tx(
  String id, {
  double shares = 1,
  double price = 100,
  double rate = 1000,
  String date = '2026-01-01',
  String time = '10:00',
  TransactionType type = TransactionType.buy,
}) => Transaction(
  id: id,
  date: date,
  time: time,
  account: 'A',
  ticker: 'XYZ',
  market: Market.us,
  name: 'Example',
  shares: shares,
  price: price,
  currency: Currency.usd,
  exchangeRate: rate,
  type: type,
);

OtherAsset asset(
  String id, {
  double value = 10000,
  Currency currency = Currency.krw,
  AssetCategory category = AssetCategory.savings,
  String date = '2026-01-01',
}) => OtherAsset(
  id: id,
  account: 'A',
  name: '예금',
  category: category,
  value: value,
  currency: currency,
  date: date,
);

StockQuote quote({
  double price = 110,
  double previous = 100,
  String currency = 'KRW',
  bool stale = false,
}) => StockQuote(
  ticker: '005930',
  name: 'Example',
  price: price,
  changePct: 10,
  closeYest: previous,
  currency: currency,
  isStale: stale,
);

Holding krHolding() => Holding(
  account: 'A',
  ticker: '005930',
  market: Market.krx,
  currency: Currency.krw,
  shares: 1,
  avgCost: 100,
  avgExchangeRate: 1,
);

void main() {
  group('ledger invariants', () {
    test(
      'finite input whose sale proceeds overflow is diagnosed before changing holdings',
      () {
        final result = replayPortfolio([
          tx(
            'gift',
            type: TransactionType.openingBalance,
            shares: 1e200,
            price: 0,
          ),
          tx(
            'overflow',
            type: TransactionType.sell,
            shares: 1e200,
            price: 1e200,
          ),
        ]);
        expect(result.realizedTrades, isEmpty);
        expect(result.issues.single.recordId, 'overflow');
        expect(result.holdings.single.shares, 1e200);
      },
    );
    test(
      'KRW costs and realized cost preserve actual purchase cash amounts',
      () {
        final result = replayPortfolio([
          tx('1'),
          tx('2', price: 200, rate: 2000),
          tx(
            '3',
            type: TransactionType.sell,
            shares: 0.5,
            price: 300,
            rate: 1500,
          ),
        ]);
        expect(result.issues, isEmpty);
        expect(result.holdings.single.shares, 1.5);
        expect(calcCostKRW(result.holdings.single), 375000);
        expect(result.realizedTrades.single.costKRW, 125000);
        expect(result.realizedTrades.single.profitKRW, 100000);
        expect(
          result.holdings.single.costKRW + result.realizedTrades.single.costKRW,
          500000,
        );
      },
    );

    test(
      'equal timestamps retain source order beyond Dart sort pivot threshold',
      () {
        final result = replayPortfolio(
          List.generate(
            40,
            (i) => tx(
              '$i',
              type: i.isEven ? TransactionType.buy : TransactionType.sell,
            ),
          ),
        );
        expect(result.issues, isEmpty);
        expect(result.holdings, isEmpty);
        expect(result.realizedTrades, hasLength(20));
      },
    );

    test(
      'invalid and duplicate records are diagnosed without poisoning good holdings',
      () {
        final result = replayPortfolio([
          tx('1'),
          tx('invalid', shares: double.nan),
          tx('1'),
          tx('oversell', shares: 10, type: TransactionType.sell),
        ]);
        expect(result.holdings.single.shares, 1);
        expect(result.issues, hasLength(3));
        expect(result.realizedTrades, isEmpty);
      },
    );

    test('historical replay excludes later trades', () {
      final result = replayPortfolio([
        tx('1'),
        tx('2', date: '2026-01-03'),
      ], throughDate: '2026-01-02');
      expect(result.holdings.single.shares, 1);
    });

    test('mixed currencies are never added as raw units', () {
      final assets = consolidateOtherAssets([
        asset('1', value: 1000),
        asset('2', value: 1000, currency: Currency.usd),
      ]);
      final result = evaluatePortfolio(
        holdings: [],
        otherAssets: assets,
        quotes: {},
        exchangeRate: 1500,
      );
      expect(assets, hasLength(2));
      expect(result.total.valueKRW, 1501000);
      expect(result.isComplete, isTrue);
    });

    test('repayment cannot turn excess payment into a second debt', () {
      final entries = [
        asset('1', category: AssetCategory.loan, value: 100),
        asset('2', category: AssetCategory.loan, value: -120),
      ];
      expect(validateOtherAssetLedger(entries).single.recordId, '2');
      final result = evaluatePortfolio(
        holdings: [],
        otherAssets: consolidateOtherAssets(entries),
        quotes: {},
        exchangeRate: 1500,
      );
      expect(result.isComplete, isFalse);
      expect(result.assets.single.valueKRW, isNull);
    });
  });

  group('valuation and snapshot quality', () {
    test(
      'portfolio and single-account daily denominators include the same assets',
      () {
        final valuation = evaluatePortfolio(
          holdings: [krHolding()],
          otherAssets: consolidateOtherAssets([asset('1')]),
          quotes: {'005930': quote()},
          exchangeRate: 1500,
        );
        expect(valuation.total.valueKRW, 10110);
        expect(valuation.total.dailyChangeKRW, 10);
        expect(
          valuation.total.dailyChangePct,
          closeTo(10 / 10100 * 100, 1e-12),
        );
        expect(
          valuation.total.dailyChangePct,
          valuation.byAccount['A']!.dailyChangePct,
        );
        final snapshot = buildCurrentSnapshot(
          valuation: valuation,
          exchangeRate: 1500,
          now: DateTime(2026, 1, 2),
        );
        expect(snapshot!.dailyChangeKRW, 10);
        expect(snapshot.schemaVersion, 2);
      },
    );

    for (final variant in ['missing', 'stale', 'previous', 'currency']) {
      test('$variant quote cannot overwrite a valid snapshot', () {
        final quotes = <String, StockQuote>{
          if (variant != 'missing')
            '005930': quote(
              stale: variant == 'stale',
              previous: variant == 'previous' ? double.nan : 100,
              currency: variant == 'currency' ? 'USD' : 'KRW',
            ),
        };
        final valuation = evaluatePortfolio(
          holdings: [krHolding()],
          otherAssets: [],
          quotes: quotes,
          exchangeRate: 1500,
        );
        expect(valuation.isDailyComplete, isFalse);
        expect(
          buildCurrentSnapshot(
            valuation: valuation,
            exchangeRate: 1500,
            now: DateTime(2026, 1, 2),
          ),
          isNull,
        );
      });
    }

    test('invalid FX leaves a USD position explicitly unvalued', () {
      final holding = replayPortfolio([tx('1')]).holdings.single;
      final valuation = evaluatePortfolio(
        holdings: [holding],
        otherAssets: [],
        quotes: {
          'XYZ': const StockQuote(
            ticker: 'XYZ',
            name: 'X',
            price: 100,
            changePct: 0,
            closeYest: 100,
            currency: 'USD',
          ),
        },
        exchangeRate: double.nan,
      );
      expect(valuation.positions.single.valueKRW, isNull);
      expect(valuation.isComplete, isFalse);
    });
  });

  group('historical prices and chart ranges', () {
    test(
      'weekend uses an observation before the requested range, never Monday',
      () {
        final saturday = DateTime(2026, 9, 5);
        expect(
          historicalValueOnOrBefore({
            '2026-09-04': 100,
            '2026-09-07': 200,
          }, saturday),
          100,
        );
        expect(
          historicalValueOnOrBefore({'2026-09-07': 200}, saturday),
          isNull,
        );
        expect(
          historicalValueOnOrBefore({'2026-08-01': 100}, saturday),
          isNull,
        );
      },
    );

    test('backfill has no fallback to a current or invented exchange rate', () {
      final result = buildHistoricalSnapshots(
        transactions: [tx('1')],
        otherAssets: [],
        pricesByTicker: {
          'XYZ': {'2025-12-31': 100, '2026-01-01': 110},
        },
        exchangeRates: {},
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 1),
      );
      expect(result.snapshots, isEmpty);
      expect(result.issues.single, contains('과거 환율'));
    });

    test(
      'backfill uses exact KRW cost and the shared daily price-change policy',
      () {
        final result = buildHistoricalSnapshots(
          transactions: [tx('1')],
          otherAssets: [asset('a')],
          pricesByTicker: {
            'XYZ': {'2025-12-31': 90, '2026-01-01': 100},
          },
          exchangeRates: {'2026-01-01': 1500},
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 1),
        );
        expect(result.issues, isEmpty);
        expect(result.snapshots.single.totalValueKRW, 160000);
        expect(result.snapshots.single.totalCostKRW, 110000);
        expect(result.snapshots.single.dailyChangeKRW, 15000);
        expect(
          result.snapshots.single.dailyChangePct,
          closeTo(15000 / 145000 * 100, 1e-9),
        );
      },
    );

    test(
      'negative portfolios generate bounded ticks and x values preserve date gaps',
      () {
        final interval = trendAxisInterval([-10000000, -20000000]);
        expect(10000000 / interval, lessThanOrEqualTo(4));
        expect(trendAxisInterval([0, 0]), greaterThan(0));
        expect(trendAxisInterval([double.nan]), greaterThan(0));
        expect(trendAxisInterval([5e-324, 1e-323]).isFinite, isTrue);
        expect(snapshotXAxis(DateTime(2026, 2, 1), DateTime(2026, 1, 1)), 31);
      },
    );
  });
}
