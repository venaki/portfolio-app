import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/holding.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/portfolio_snapshot.dart';
import 'package:portfolio_flutter/models/sheet_schema.dart';
import 'package:portfolio_flutter/models/stock_quote.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/utils/format.dart';

void main() {
  final transactionRow = [
    'id',
    '2026-01-01',
    'A',
    'buy',
    '5930',
    'KRX',
    '삼성전자',
    '0.25',
    '100',
    'KRW',
    '1',
    '',
    'B',
    '14:32',
  ];

  test(
    'canonical holding keys separate markets while preserving legacy order',
    () {
      final a = Holding(
        account: 'A|B',
        broker: 'C',
        ticker: '005930',
        market: Market.krx,
        currency: Currency.krw,
        shares: 1,
        avgCost: 100,
        avgExchangeRate: 1,
      );
      final b = Holding(
        account: 'A|B',
        broker: 'C',
        ticker: '005930',
        market: Market.kosdaq,
        currency: Currency.krw,
        shares: 1,
        avgCost: 100,
        avgExchangeRate: 1,
      );
      expect(AppSettings.holdingKeyFor(a), isNot(AppSettings.holdingKeyFor(b)));
      final legacy = AppSettings(
        holdingOrder: [AppSettings.holdingKey(a.ticker, a.account, a.broker)],
      );
      expect(legacy.holdingOrderIndex(a), 0);
      final current = AppSettings(
        holdingOrder: [
          AppSettings.holdingKeyFor(b),
          AppSettings.holdingKeyFor(a),
        ],
      );
      expect(current.holdingOrderIndex(a), 1);
      expect(current.holdingOrderIndex(b), 0);
    },
  );

  test(
    'transaction schema preserves all fourteen columns and normalizes ticker',
    () {
      final tx = Transaction.fromSheetRow(transactionRow);
      expect(Transaction.sheetHeaders, hasLength(14));
      expect(tx.time, '14:32');
      expect(tx.ticker, '005930');
      expect(Transaction.fromSheetRow(tx.toSheetRow()).shares, 0.25);
      expect(
        Transaction.fromSheetRow(transactionRow.sublist(0, 13)).time,
        '00:00',
      );
    },
  );

  test(
    'malformed values are rejected instead of silently becoming valid zero trades',
    () {
      for (final change in [
        (1, '2026-02-30'),
        (3, 'unexpected'),
        (5, 'UNKNOWN'),
        (7, 'NaN'),
        (8, 'Infinity'),
        (9, 'EUR'),
        (13, '25:00'),
      ]) {
        final row = [...transactionRow]..[change.$1] = change.$2;
        expect(() => Transaction.fromSheetRow(row), throwsFormatException);
      }
      expect(() => Transaction.fromSheetRow([]), throwsFormatException);
    },
  );

  test('Korean alphanumeric codes survive transaction and quote imports', () {
    for (final code in ['0195R0', '00088K', '005930']) {
      final row = [...transactionRow]..[4] = code.toLowerCase();
      final tx = Transaction.fromSheetRow(row);
      expect(tx.ticker, code);
      expect(Transaction.fromSheetRow(tx.toSheetRow()).ticker, code);
      final quote = StockQuote.fromSheetRow([
        code.toLowerCase(),
        'KRX',
        'KRX:$code',
        '100',
        'Example',
        '0',
        '100',
        'KRW',
      ]);
      expect(quote.ticker, tx.ticker);
    }
    for (final code in ['0195R', '0195R00', '0195.R', '=1+100', '삼성전자']) {
      final row = [...transactionRow]..[4] = code;
      expect(
        () => Transaction.fromSheetRow(row),
        throwsFormatException,
        reason: code,
      );
    }
  });

  test('asset row supports legacy cash category and time defaults', () {
    final asset = OtherAsset.fromSheetRow([
      'a',
      'A',
      'Cash',
      'cash',
      '100',
      'USD',
      '2026-01-01',
    ]);
    expect(asset.category, AssetCategory.savings);
    expect(asset.time, '00:00');
    expect(asset.toSheetRow(), hasLength(SheetSchema.otherAssets.length));
    expect(
      () => OtherAsset.fromSheetRow([
        'a',
        'A',
        'X',
        'loan',
        '#N/A',
        'KRW',
        '2026-01-01',
      ]),
      throwsFormatException,
    );
  });

  test('settings JSON round trip preserves commas and Unicode in names', () {
    const settings = AppSettings(
      accounts: ['가족, 공동', 'A'],
      brokers: ['Broker, Inc.'],
      holdingOrder: ['XYZ|가족, 공동|Broker, Inc.'],
    );
    final parsed = AppSettings.fromSheetRows(settings.toSheetRows());
    expect(parsed.accounts, settings.accounts);
    expect(parsed.brokers, settings.brokers);
    expect(parsed.holdingOrder, settings.holdingOrder);
    expect(parsed.schemaVersion, 2);
    final legacy = AppSettings.fromSheetRows([
      ['accounts', 'A,B'],
      ['holding_order', 'X|A|B,Y|B|A'],
    ]);
    expect(legacy.accounts, ['A', 'B']);
    expect(legacy.holdingOrder, ['X|A|B', 'Y|B|A']);
    expect(legacy.schemaVersion, 1);
  });

  test(
    'duplicate nonblank settings keys are rejected before values diverge',
    () {
      for (final key in ['refresh_interval', 'custom_setting']) {
        expect(
          () => AppSettings.fromSheetRows([
            [key, '60'],
            [key, '120'],
          ]),
          throwsFormatException,
        );
        expect(
          () => AppSettings.fromSheetRows([
            [key],
            [key, '60'],
          ]),
          throwsFormatException,
        );
      }
      expect(
        AppSettings.fromSheetRows([
          [],
          ['', 'ignored'],
          ['', 'also ignored'],
          ['refresh_interval', '90'],
        ]).refreshInterval,
        90,
      );
    },
  );

  test('unsafe settings are rejected before timers and theme construction', () {
    for (final row in [
      ['refresh_interval', '0'],
      ['refresh_interval', '-1'],
      ['force_refresh_wait', '0'],
      ['accent_color', 'bad'],
      ['accounts', '[4]'],
    ]) {
      expect(() => AppSettings.fromSheetRows([row]), throwsFormatException);
    }
    expect(
      AppSettings.fromSheetRows([
        ['exchange_rate', '#N/A'],
      ]).exchangeRate,
      isNull,
    );
  });

  test(
    'quote missingness and stale state survive without turning into zero price',
    () {
      final quote = StockQuote.fromSheetRow([
        'X',
        'US',
        '',
        '#N/A',
        'Name',
        '',
        '',
        'USD',
      ]);
      expect(quote.hasError, isTrue);
      expect(quote.price.isNaN, isTrue);
      expect(quote.hasPreviousClose, isFalse);
      final stale = quote.copyWith(
        price: 10,
        isStale: true,
        fetchedAt: DateTime(2026),
      );
      expect(stale.hasValidPrice, isTrue);
      expect(stale.isStale, isTrue);
    },
  );

  test(
    'fractional quantities remain visible and invalid data cannot crash formatting',
    () {
      expect(formatShares(0.25), '0.25');
      expect(formatShares(0.5), '0.5');
      expect(formatShares(1234.125), '1,234.125');
      expect(formatKRW(double.nan), '—');
      expect(formatPercent(double.infinity), '—');
      expect(formatRelativeTime('not-a-date'), '시간 확인 불가');
    },
  );

  test(
    'invalid snapshot rows are rejected, legacy math versions can be identified',
    () {
      final row = [
        'snapshot-2026-01-01',
        '2026-01-01',
        '100',
        '100',
        '0',
        '0',
        '0',
        '0',
        '1500',
        'live',
        '2026-01-01T12:00:00',
        '1',
      ];
      expect(PortfolioSnapshot.fromSheetRow(row).needsRebuild, isTrue);
      row[2] = 'NaN';
      expect(() => PortfolioSnapshot.fromSheetRow(row), throwsFormatException);
    },
  );
}
