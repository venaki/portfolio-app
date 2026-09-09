import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/services/mock_sheets_service.dart';
import 'package:portfolio_flutter/services/portfolio_backup.dart';
import 'package:portfolio_flutter/services/sheets_service.dart';

Transaction exampleTransaction({String memo = '=IMPORTDATA("example")'}) =>
    Transaction(
      id: 'trade',
      date: '2026-01-02',
      time: '15:45',
      account: 'A',
      type: TransactionType.buy,
      ticker: 'XYZ',
      market: Market.us,
      name: 'Example',
      shares: 0.25,
      price: 100,
      currency: Currency.usd,
      exchangeRate: 1450,
      memo: memo,
    );
PortfolioBackup exampleBackup() => PortfolioBackup(
  transactions: [exampleTransaction()],
  otherAssets: [],
  settings: const AppSettings(accounts: ['A'], brokers: ['B,C']),
  exchangeRateSource: '1400',
  extraSettings: const {'history_dirty_from': '2026-01-02', 'custom': '=1+1'},
  historicalPrices: HistoricalPriceImport.fromRows([
    ['2026-01-02', 'XYZ', '100'],
    ['2026-01-02', 'USDKRW', '1400'],
  ]),
);

void main() {
  test(
    'full backup restores ledger, exact time, settings and historical data',
    () async {
      final original = exampleBackup();
      final decoded = PortfolioBackup.fromJsonText(original.toJsonText());
      final repository = MockSheetsService().forSpreadsheet('restored');
      await repository.restoreBackup(decoded);
      final data = await repository.loadAll();
      expect(data.transactions.single.time, '15:45');
      expect(data.transactions.single.shares, 0.25);
      expect(data.transactions.single.memo, '=IMPORTDATA("example")');
      expect(data.settings.brokers, ['B,C']);
      expect(data.exchangeRate, 1400);
      expect(repository.historyDirtyFrom, '2026-01-02');
      final exported = await repository.createBackup();
      expect(exported.extraSettings['custom'], '=1+1');
      expect(
        exported.historicalPrices.toRows(),
        original.historicalPrices.toRows(),
      );
    },
  );

  test(
    'restore uses one atomic batch and only approved fields become formulas',
    () async {
      final mutations = <http.Request>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'properties': {'title': 'Test'},
              'sheets': [
                for (final (index, title) in [
                  'Transactions',
                  'Prices',
                  'OtherAssets',
                  'Settings',
                  'Snapshots',
                  'HistoricalPrices',
                ].indexed)
                  {
                    'properties': {
                      'sheetId': index,
                      'title': title,
                      'gridProperties': {'rowCount': 1000, 'columnCount': 26},
                    },
                  },
              ],
            }),
            200,
          );
        }
        mutations.add(request);
        return http.Response('{}', 200);
      });
      final repository = SheetsService(
        getAuthHeaders: () async => {},
        client: client,
        spreadsheetId: 'test',
      );
      addTearDown(repository.close);
      await repository.restoreBackup(exampleBackup());
      expect(mutations, hasLength(1));
      expect(mutations.single.url.path, endsWith(':batchUpdate'));
      final requests = (jsonDecode(mutations.single.body)['requests'] as List);
      expect(requests, hasLength(6));
      final cells = requests.first['updateCells'];
      expect(
        cells['range']['endRowIndex'],
        1000,
      ); // Clears old trailing data atomically.
      expect(cells['rows'][1]['values'][11]['userEnteredValue'], {
        'stringValue': '=IMPORTDATA("example")',
      });
      final settings = requests[2]['updateCells']['rows'] as List;
      expect(
        settings.any((r) => r['values'][1]['userEnteredValue'] == null),
        isFalse,
      );
      final custom = settings.last['values'][1]['userEnteredValue'];
      expect(custom, {'stringValue': '=1+1'});
    },
  );

  test('rejects a partial, incompatible or invalid ledger before restore', () {
    final encoded =
        jsonDecode(exampleBackup().toJsonText()) as Map<String, dynamic>;
    encoded['otherAssets'] = null;
    expect(
      () => PortfolioBackup.fromJsonText(jsonEncode(encoded)),
      throwsFormatException,
    );
    encoded['otherAssets'] = [];
    encoded['transactions'] = [
      exampleTransaction().toSheetRow(),
      exampleTransaction().toSheetRow(),
    ];
    expect(
      () => PortfolioBackup.fromJsonText(jsonEncode(encoded)),
      throwsFormatException,
    );
    expect(
      () => PortfolioBackup(
        transactions: [],
        otherAssets: [],
        settings: const AppSettings(),
        exchangeRateSource: '=IMPORTDATA("https://example.com")',
      ).validate(),
      throwsFormatException,
    );
  });

  test('legacy schema preserves time and refuses unknown collections', () {
    final legacy = <String, dynamic>{
      'schemaVersion': 1,
      'accounts': ['A'],
      'settings': {},
      'transactions': [
        {
          'id': 'legacy',
          'executedAt': '2026-01-02T15:45:00',
          'owner': 'A',
          'type': 'buy',
          'ticker': 'XYZ',
          'shares': 1,
          'price': 100,
          'currency': 'USD',
          'exchangeRate': 1400,
        },
      ],
    };
    expect(
      PortfolioBackup.fromJsonText(jsonEncode(legacy)).transactions.single.time,
      '15:45',
    );
    legacy['otherAssets'] = [];
    expect(
      () => PortfolioBackup.fromJsonText(jsonEncode(legacy)),
      throwsFormatException,
    );
    legacy.remove('otherAssets');
    legacy['schemaVersion'] = 2;
    expect(
      () => PortfolioBackup.fromJsonText(jsonEncode(legacy)),
      throwsFormatException,
    );
  });
}
