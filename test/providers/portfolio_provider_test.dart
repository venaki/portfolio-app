import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/portfolio_snapshot.dart';
import 'package:portfolio_flutter/models/stock_quote.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/providers/portfolio_provider.dart';
import 'package:portfolio_flutter/services/portfolio_backup.dart';
import 'package:portfolio_flutter/services/sheets_service.dart';

Transaction trade(
  String id, {
  double price = 100,
  double rate = 1000,
  String date = '2026-01-01',
}) => Transaction(
  id: id,
  date: date,
  time: '10:00',
  account: 'A',
  type: TransactionType.buy,
  ticker: 'XYZ',
  market: Market.us,
  name: 'Example',
  shares: 1,
  price: price,
  currency: Currency.usd,
  exchangeRate: rate,
);

const healthyQuote = StockQuote(
  ticker: 'XYZ',
  name: 'Example',
  price: 250,
  closeYest: 240,
  changePct: 4.16,
  currency: 'USD',
);

class ControlledFactory extends SheetsService {
  final Map<String, ControlledRepository> repositories;
  ControlledFactory(this.repositories)
    : super(
        getAuthHeaders: () async => {},
        client: MockClient(
          (_) async => throw StateError('Unexpected network request'),
        ),
      );
  @override
  SheetsService forSpreadsheet(String id) => repositories[id]!;
}

class ControlledRepository extends SheetsService {
  List<Transaction> transactions;
  List<OtherAsset> assets = [];
  List<StockQuote> quotes = [healthyQuote];
  final List<PortfolioSnapshot> savedSnapshots = [];
  AppSettings settings = const AppSettings(accounts: ['A']);
  double rate = 1500;
  Object? loadError,
      priceError,
      writeError,
      snapshotError,
      snapshotReadError,
      backupError;
  Completer<void>? loadGate, priceGate, backupGate;
  final loadEntered = Completer<void>();
  final priceEntered = Completer<void>();
  final backupEntered = Completer<void>();
  int snapshotWrites = 0;
  int priceReads = 0;

  ControlledRepository(String id, {List<Transaction>? seed})
    : transactions = seed ?? [trade('initial')],
      super(
        getAuthHeaders: () async => {},
        spreadsheetId: id,
        client: MockClient(
          (_) async => throw StateError('Unexpected network request'),
        ),
      ) {
    exchangeRateValid = true;
  }

  @override
  Future<PortfolioData> loadAll() async {
    if (!loadEntered.isCompleted) loadEntered.complete();
    if (loadGate != null) await loadGate!.future;
    if (loadError != null) throw loadError!;
    exchangeRateValid = rate.isFinite && rate > 0;
    return (
      transactions: [...transactions],
      quotes: [...quotes],
      exchangeRate: rate,
      otherAssets: [...assets],
      settings: settings,
    );
  }

  @override
  Future<PriceData> loadPrices() async {
    priceReads++;
    if (!priceEntered.isCompleted) priceEntered.complete();
    if (priceGate != null) await priceGate!.future;
    if (priceError != null) throw priceError!;
    exchangeRateValid = rate.isFinite && rate > 0;
    return (quotes: [...quotes], exchangeRate: rate);
  }

  @override
  Future<List<PortfolioSnapshot>> loadSnapshots() async {
    if (snapshotReadError != null) throw snapshotReadError!;
    return [...savedSnapshots];
  }

  @override
  Future<PortfolioBackup> createBackup() async {
    if (!backupEntered.isCompleted) backupEntered.complete();
    if (backupGate != null) await backupGate!.future;
    if (backupError != null) throw backupError!;
    return PortfolioBackup(
      transactions: [...transactions],
      otherAssets: [...assets],
      settings: settings,
      snapshots: [...savedSnapshots],
    );
  }

  @override
  Future<void> upsertSnapshot(PortfolioSnapshot snapshot) async {
    if (snapshotError != null) throw snapshotError!;
    snapshotWrites++;
    savedSnapshots.removeWhere((s) => s.date == snapshot.date);
    savedSnapshots.add(snapshot);
  }

  @override
  Future<void> addPriceRow(
    String ticker,
    String market,
    String currency,
  ) async {}
  @override
  Future<void> setHistoryDirtyFrom(String? date) async {
    historyDirtyFrom = date;
  }

  @override
  Future<void> addTransaction(Transaction tx) async {
    if (writeError != null) throw writeError!;
    transactions.add(tx);
  }

  @override
  Future<void> updateTransaction(Transaction tx) async {
    if (writeError != null) throw writeError!;
    transactions[transactions.indexWhere((t) => t.id == tx.id)] = tx;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (writeError != null) throw writeError!;
    transactions.removeWhere((t) => t.id == id);
  }
}

void main() {
  late ControlledRepository a, b;
  late ControlledFactory factory;
  late PortfolioNotifier notifier;
  setUp(() {
    a = ControlledRepository('sheet-A');
    b = ControlledRepository('sheet-B', seed: [trade('other', price: 200)]);
    factory = ControlledFactory({'sheet-A': a, 'sheet-B': b});
    notifier = PortfolioNotifier(
      factory,
      enableTimer: false,
      now: () => DateTime(2026, 1, 10, 12),
    );
  });
  tearDown(() {
    notifier.dispose();
    factory.close();
    a.close();
    b.close();
  });

  test(
    'failed connection preserves the previous connected data and write destination',
    () async {
      await notifier.connect('sheet-A');
      b.loadError = const SheetsApiException('Forbidden', statusCode: 403);
      await expectLater(
        notifier.connect('sheet-B'),
        throwsA(isA<SheetsApiException>()),
      );
      expect(notifier.state.spreadsheetId, 'sheet-A');
      expect(notifier.state.transactions.single.id, 'initial');
      await notifier.addTransaction(trade('after-failure'));
      expect(a.transactions.map((t) => t.id), contains('after-failure'));
      expect(b.transactions.map((t) => t.id), isNot(contains('after-failure')));
    },
  );

  test(
    'optional snapshot failure does not roll a successful connection back to old data',
    () async {
      await notifier.connect('sheet-A');
      b.snapshotError = const SheetsApiException(
        'Snapshot denied',
        statusCode: 403,
      );
      await notifier.connect('sheet-B');
      expect(notifier.state.spreadsheetId, 'sheet-B');
      expect(notifier.state.transactions.single.id, 'other');
      expect(notifier.state.error, isNotNull);
      await notifier.addTransaction(trade('saved-in-b'));
      expect(b.transactions.map((t) => t.id), contains('saved-in-b'));
      expect(a.transactions.map((t) => t.id), isNot(contains('saved-in-b')));
    },
  );

  test(
    'history read failure preserves the core portfolio without overwriting history',
    () async {
      a.snapshotReadError = const SheetsApiException(
        'History unavailable',
        statusCode: 403,
      );
      await notifier.connect('sheet-A');
      expect(notifier.state.spreadsheetId, 'sheet-A');
      expect(notifier.state.transactions.single.id, 'initial');
      expect(notifier.state.dataIssues, isEmpty);
      expect(notifier.state.error, contains('과거 기록'));
      expect(a.snapshotWrites, 0);
    },
  );

  test('late connection cannot overwrite a newer session', () async {
    a.loadGate = Completer<void>();
    final first = notifier.connect('sheet-A');
    final rejected = expectLater(first, throwsStateError);
    await a.loadEntered.future;
    await notifier.connect('sheet-B');
    a.loadGate!.complete();
    await rejected;
    expect(notifier.state.spreadsheetId, 'sheet-B');
    expect(notifier.state.transactions.single.id, 'other');
    expect(a.snapshotWrites, 0);
  });

  test(
    'a delayed refresh from the old sheet cannot update a newly connected sheet',
    () async {
      await notifier.connect('sheet-A');
      a.priceGate = Completer<void>();
      final oldRefresh = notifier.refreshPrices();
      await a.priceEntered.future;
      await notifier.connect('sheet-B');
      a.priceGate!.complete();
      await oldRefresh;
      expect(notifier.state.spreadsheetId, 'sheet-B');
      expect(notifier.state.transactions.single.id, 'other');
      expect(a.snapshotWrites, 1);
      expect(b.snapshotWrites, 1);
    },
  );

  for (final status in [401, 403, 429]) {
    test(
      'HTTP $status save failure leaves both local and repository ledgers unchanged',
      () async {
        await notifier.connect('sheet-A');
        a.writeError = SheetsApiException('Save denied', statusCode: status);
        await expectLater(
          notifier.addTransaction(trade('failed')),
          throwsA(
            isA<SheetsApiException>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
        expect(notifier.state.transactions.map((t) => t.id), ['initial']);
        expect(a.transactions.map((t) => t.id), ['initial']);
        expect(notifier.state.isSaving, isFalse);
        expect(notifier.state.error, isNotNull);
      },
    );
  }

  test(
    'missing quotes retain the last known price and protect the saved snapshot',
    () async {
      await notifier.connect('sheet-A');
      final previous = notifier.state.snapshots.single;
      a.quotes = [];
      await notifier.refreshPrices();
      expect(notifier.state.quotes['XYZ']!.price, 250);
      expect(notifier.state.quotes['XYZ']!.isStale, isTrue);
      expect(notifier.state.staleTickers, contains('XYZ'));
      expect(a.snapshotWrites, 1);
      expect(notifier.state.snapshots.single, same(previous));
    },
  );

  test(
    'invalid FX does not overwrite normal FX or the saved snapshot',
    () async {
      await notifier.connect('sheet-A');
      a.rate = double.nan;
      await notifier.refreshPrices();
      expect(notifier.state.exchangeRate, 1500);
      expect(notifier.state.staleTickers, contains('USDKRW'));
      expect(a.snapshotWrites, 1);
    },
  );

  test(
    'post-save missing prices are stale and cannot replace a snapshot',
    () async {
      await notifier.connect('sheet-A');
      a.quotes = [];
      await notifier.addTransaction(trade('committed'));
      expect(notifier.state.transactions, hasLength(2));
      expect(notifier.state.quotes['XYZ']!.isStale, isTrue);
      expect(notifier.state.staleTickers, contains('XYZ'));
      expect(a.snapshotWrites, 1);
    },
  );

  test(
    'past edits persist the earliest dirty date and recompute exact current KRW cost',
    () async {
      await notifier.connect('sheet-A');
      await notifier.addTransaction(
        trade('second', price: 200, rate: 2000, date: '2026-01-02'),
      );
      expect(notifier.state.holdings.single.costKRW, 500000);
      expect(notifier.state.snapshots.single.totalCostKRW, 500000);
      expect(notifier.state.historyDirtyFrom, '2026-01-02');
      await notifier.updateTransaction(
        trade('initial', price: 120, date: '2026-01-01'),
      );
      expect(notifier.state.historyDirtyFrom, '2026-01-01');
      expect(a.historyDirtyFrom, '2026-01-01');
      expect(notifier.state.holdings.single.costKRW, 520000);
    },
  );

  test(
    'a committed write remains successful when the subsequent price read fails',
    () async {
      await notifier.connect('sheet-A');
      a.priceError = const SheetsApiException('Offline');
      await notifier.addTransaction(trade('committed'));
      expect(a.transactions.map((t) => t.id), contains('committed'));
      expect(
        notifier.state.transactions.map((t) => t.id),
        contains('committed'),
      );
      expect(notifier.state.error, contains('저장은 완료'));
      expect(notifier.state.isSaving, isFalse);
    },
  );

  test(
    'today additions do not incorrectly mark past observations as dirty',
    () async {
      await notifier.connect('sheet-A');
      await notifier.addTransaction(trade('today', date: '2026-01-10'));
      expect(notifier.state.historyDirtyFrom, isNull);
      expect(a.historyDirtyFrom, isNull);
    },
  );

  test(
    'future-dated stock and other assets are excluded from current valuation',
    () async {
      a.transactions.add(trade('future', date: '2026-01-11'));
      a.assets = [
        const OtherAsset(
          id: 'current',
          account: 'A',
          name: 'Savings',
          category: AssetCategory.savings,
          value: 100,
          currency: Currency.krw,
          date: '2026-01-10',
        ),
        const OtherAsset(
          id: 'future',
          account: 'A',
          name: 'Savings',
          category: AssetCategory.savings,
          value: 200,
          currency: Currency.krw,
          date: '2026-01-11',
        ),
      ];
      await notifier.connect('sheet-A');
      expect(notifier.state.transactions, hasLength(2));
      expect(notifier.state.holdings.single.shares, 1);
      expect(notifier.state.consolidatedOtherAssets.single.totalValue, 100);
      expect(notifier.state.snapshots.single.totalValueKRW, 375100);
    },
  );

  test(
    'nullable state fields clear explicitly rather than retaining old errors',
    () {
      const state = PortfolioState(
        error: 'old',
        historyDirtyFrom: '2026-01-01',
      );
      expect(state.copyWith(error: null).error, isNull);
      expect(state.copyWith(historyDirtyFrom: null).historyDirtyFrom, isNull);
      expect(state.copyWith().historyDirtyFrom, '2026-01-01');
    },
  );

  test(
    'backup reads block mutations and refresh until the export finishes',
    () async {
      await notifier.connect('sheet-A');
      a.backupGate = Completer<void>();
      final pending = notifier.createBackup();
      await a.backupEntered.future;
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.canWrite, isFalse);
      final priceReads = a.priceReads;
      await notifier.refreshPrices();
      expect(a.priceReads, priceReads);
      await expectLater(
        notifier.addTransaction(trade('blocked')),
        throwsStateError,
      );
      expect(a.transactions.map((t) => t.id), ['initial']);
      a.backupGate!.complete();
      final backup = await pending;
      expect(backup.transactions.map((t) => t.id), ['initial']);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.canWrite, isTrue);
      await notifier.addTransaction(trade('after-backup'));
      expect(a.transactions.map((t) => t.id), ['initial', 'after-backup']);
    },
  );

  test(
    'failed backup reads release the operation lock and preserve the ledger',
    () async {
      await notifier.connect('sheet-A');
      a.backupGate = Completer<void>();
      a.backupError = const SheetsApiException(
        'Backup denied',
        statusCode: 403,
      );
      final pending = notifier.createBackup();
      final failure = expectLater(pending, throwsA(isA<SheetsApiException>()));
      await a.backupEntered.future;
      expect(notifier.state.isLoading, isTrue);
      a.backupGate!.complete();
      await failure;
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.canWrite, isTrue);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.transactions.map((t) => t.id), ['initial']);
      await notifier.addTransaction(trade('after-failed-backup'));
      expect(a.transactions.map((t) => t.id), [
        'initial',
        'after-failed-backup',
      ]);
    },
  );
}
