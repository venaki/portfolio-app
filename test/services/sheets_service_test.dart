import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portfolio_flutter/models/app_settings.dart';
import 'package:portfolio_flutter/models/other_asset.dart';
import 'package:portfolio_flutter/models/transaction.dart';
import 'package:portfolio_flutter/services/sheets_service.dart';

const transaction = Transaction(
  id: 'transaction-1',
  date: '2026-01-01',
  time: '14:32',
  account: 'A',
  broker: 'Broker',
  type: TransactionType.buy,
  ticker: 'XYZ',
  market: Market.us,
  name: 'Example',
  shares: 0.25,
  price: 100,
  currency: Currency.usd,
  exchangeRate: 1500,
  memo: '=IMPORTDATA("untrusted")',
);

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object> metadata() => {
  'properties': {'title': 'Portfolio'},
  'sheets': [
    for (final title in [
      'Transactions',
      'Prices',
      'OtherAssets',
      'Settings',
      'Snapshots',
      'HistoricalPrices',
    ])
      {
        'properties': {
          'title': title,
          'sheetId': title.hashCode,
          'gridProperties': {'rowCount': 1000, 'columnCount': 26},
        },
      },
  ],
};

Map<String, Object> batchData({
  List<List<String>>? transactions,
  List<String>? transactionHeaders,
}) => {
  'valueRanges': [
    {
      'values': [
        transactionHeaders ?? Transaction.sheetHeaders,
        ...?transactions,
      ],
    },
    {
      'values': [
        [
          'ticker',
          'market',
          'googlefinance_key',
          'price',
          'name',
          'changepct',
          'closeyest',
          'currency',
        ],
        ['XYZ', 'US', 'XYZ', '100', 'Example', '0', '100', 'USD'],
      ],
    },
    {
      'values': [OtherAsset.sheetHeaders],
    },
    {
      'values': [
        ['accounts', '["A"]'],
        ['brokers', '["Broker"]'],
        ['exchange_rate', '1500'],
      ],
    },
  ],
};

SheetsService service(http.Client client) => SheetsService(
  getAuthHeaders: () async => {'Authorization': 'Bearer unit-test'},
  client: client,
  spreadsheetId: 'sheet-A',
);

void main() {
  test(
    'valid alphanumeric Korean rows do not trigger the save restriction',
    () async {
      final rows = [
        for (final code in ['0195R0', '00088K', '5930'])
          transaction.toSheetRow()
            ..[0] = 'tx-$code'
            ..[4] = code
            ..[5] = 'KRX'
            ..[9] = 'KRW'
            ..[10] = '1',
      ];
      final client = MockClient(
        (request) async => request.url.path.endsWith('values:batchGet')
            ? jsonResponse(batchData(transactions: rows))
            : jsonResponse(metadata()),
      );
      final repository = service(client);
      addTearDown(repository.close);
      final data = await repository.loadAll();
      expect(data.transactions.map((t) => t.ticker), [
        '0195R0',
        '00088K',
        '005930',
      ]);
      expect(repository.dataIssues, isEmpty);
    },
  );

  test(
    'Korean price rows preserve alphanumeric codes and avoid duplicates',
    () async {
      final writes = <List<dynamic>>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return jsonResponse({'values': writes});
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        for (final raw in body['values'] as List) {
          final row = List<dynamic>.from(raw as List);
          expect(row[0], "'0195R0");
          expect(row[2], 'KRX:0195R0');
          expect(row[3], '=GOOGLEFINANCE("KRX:0195R0","price")');
          row[0] =
              '0195R0'; // Sheets stores the apostrophe-prefixed code as text.
          writes.add(row);
        }
        return jsonResponse({});
      });
      final repository = service(client);
      addTearDown(repository.close);
      await repository.addPriceRow('0195r0', 'KRX', 'KRW');
      await repository.addPriceRow('0195R0', 'KRX', 'KRW');
      expect(writes, hasLength(1));
      await expectLater(
        repository.addPriceRow('0195.R', 'KRX', 'KRW'),
        throwsFormatException,
      );
      expect(writes, hasLength(1));
    },
  );

  test(
    'real repository reads and preserves all fourteen transaction columns',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('values:batchGet')) {
          return jsonResponse(
            batchData(transactions: [transaction.toSheetRow()]),
          );
        }
        return jsonResponse(metadata());
      });
      final repository = service(client);
      addTearDown(repository.close);
      final data = await repository.loadAll();
      expect(data.transactions.single.time, '14:32');
      expect(data.transactions.single.shares, 0.25);
      expect(data.transactions.single.memo, transaction.memo);
      expect(repository.dataIssues, isEmpty);
    },
  );

  test(
    'malformed rows are reported individually without dropping valid records',
    () async {
      final bad = transaction.toSheetRow()..[0] = 'bad';
      bad[7] = 'NaN';
      final client = MockClient(
        (request) async => request.url.path.endsWith('values:batchGet')
            ? jsonResponse(
                batchData(transactions: [transaction.toSheetRow(), bad]),
              )
            : jsonResponse(metadata()),
      );
      final repository = service(client);
      addTearDown(repository.close);
      final data = await repository.loadAll();
      expect(data.transactions.single.id, transaction.id);
      expect(repository.dataIssues.single, contains('Transactions 3행'));
    },
  );

  for (final column in [11, 12, 13]) {
    test(
      'transaction header position $column is validated when present',
      () async {
        final headers = [...Transaction.sheetHeaders]
          ..[column] = 'wrong_column';
        final client = MockClient((request) async {
          if (request.url.path.endsWith('values:batchGet')) {
            return jsonResponse(batchData(transactionHeaders: headers));
          }
          return jsonResponse(metadata());
        });
        final repository = service(client);
        addTearDown(repository.close);
        await expectLater(repository.loadAll(), throwsFormatException);
      },
    );
  }

  test(
    'legacy eleven-column transactions retain safe optional defaults',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('values:batchGet')) {
          return jsonResponse(
            batchData(
              transactionHeaders: Transaction.sheetHeaders.take(11).toList(),
              transactions: [transaction.toSheetRow().take(11).toList()],
            ),
          );
        }
        return jsonResponse(metadata());
      });
      final repository = service(client);
      addTearDown(repository.close);
      final data = await repository.loadAll();
      expect(data.transactions.single.id, transaction.id);
      expect(data.transactions.single.memo, isEmpty);
      expect(data.transactions.single.broker, isEmpty);
      expect(data.transactions.single.time, '00:00');
      expect(repository.dataIssues, isEmpty);
    },
  );

  for (final status in [401, 403, 429]) {
    for (final operation in ['append', 'update', 'delete', 'settings']) {
      test(
        '$operation rejects HTTP $status instead of reporting save success',
        () async {
          final client = MockClient((request) async {
            if (request.method != 'GET') {
              return jsonResponse({
                'error': {'message': 'private detail'},
              }, status);
            }
            if (request.url.path.contains('Settings')) {
              return jsonResponse({
                'values': const AppSettings(accounts: ['A']).toSheetRows(),
              });
            }
            return jsonResponse({
              'values': operation == 'append' ? [] : [transaction.toSheetRow()],
            });
          });
          final repository = service(client);
          addTearDown(repository.close);
          final action = switch (operation) {
            'append' => repository.addTransaction(transaction),
            'update' => repository.updateTransaction(transaction),
            'delete' => repository.deleteTransaction(transaction.id),
            _ => repository.saveSettings(const AppSettings(accounts: ['A'])),
          };
          await expectLater(
            action,
            throwsA(
              isA<SheetsApiException>().having(
                (error) => error.statusCode,
                'statusCode',
                status,
              ),
            ),
          );
        },
      );
    }
  }

  test(
    'user text is written as RAW and preserves fractional quantities and time',
    () async {
      final writes = <http.Request>[];
      final client = MockClient((request) async {
        if (request.method == 'GET') return jsonResponse({'values': []});
        writes.add(request);
        return jsonResponse({'updates': {}});
      });
      final repository = service(client);
      addTearDown(repository.close);
      await repository.addTransaction(transaction);
      expect(writes.single.url.queryParameters['valueInputOption'], 'RAW');
      final row =
          (jsonDecode(writes.single.body)['values'] as List).single as List;
      expect(row[11], transaction.memo);
      expect(row[13], '14:32');
      expect(row[7], '0.25');
    },
  );

  test(
    'concurrent sessions never redirect a delayed write to another spreadsheet',
    () async {
      final releaseA = Completer<void>();
      final enteredA = Completer<void>();
      final writeIds = <String>[];
      final client = MockClient((request) async {
        final id = request.url.pathSegments[2];
        if (request.method == 'GET') {
          if (id == 'sheet-A') {
            enteredA.complete();
            await releaseA.future;
          }
          return jsonResponse({'values': []});
        }
        writeIds.add(id);
        return jsonResponse({});
      });
      final factory = SheetsService(
        getAuthHeaders: () async => {},
        client: client,
      );
      addTearDown(factory.close);
      final a = factory.forSpreadsheet('sheet-A');
      final b = factory.forSpreadsheet('sheet-B');
      final pendingA = a.addTransaction(transaction);
      await enteredA.future;
      await b.addTransaction(transaction);
      expect(() => a.setSpreadsheetId('sheet-B'), throwsStateError);
      releaseA.complete();
      await pendingA;
      expect(writeIds, ['sheet-B', 'sheet-A']);
      expect(a.spreadsheetId, 'sheet-A');
      expect(b.spreadsheetId, 'sheet-B');
    },
  );

  test(
    'changed remote records are rejected before a destructive overwrite',
    () async {
      var changed = false;
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          writes++;
          return jsonResponse({});
        }
        if (request.url.path.endsWith('values:batchGet')) {
          return jsonResponse(
            batchData(transactions: [transaction.toSheetRow()]),
          );
        }
        if (!request.url.path.contains('/values/')) {
          return jsonResponse(metadata());
        }
        final row = transaction.toSheetRow();
        if (changed) row[7] = '5';
        return jsonResponse({
          'values': [row],
        });
      });
      final repository = service(client);
      addTearDown(repository.close);
      await repository.loadAll();
      changed = true;
      await expectLater(
        repository.deleteTransaction(transaction.id),
        throwsA(isA<SheetsApiException>()),
      );
      expect(writes, 0);
    },
  );

  for (final operation in ['update', 'delete']) {
    test(
      'an idempotent append retains the baseline for later $operation',
      () async {
        var changed = false;
        var writes = 0;
        final client = MockClient((request) async {
          if (request.method != 'GET') {
            writes++;
            return jsonResponse({});
          }
          final row = transaction.toSheetRow();
          if (changed) row[7] = '5';
          return jsonResponse({
            'values': [row],
          });
        });
        final repository = service(client);
        addTearDown(repository.close);
        await repository.addTransaction(transaction);
        expect(writes, 0);
        changed = true;
        await expectLater(
          operation == 'update'
              ? repository.updateTransaction(transaction)
              : repository.deleteTransaction(transaction.id),
          throwsA(isA<SheetsApiException>()),
        );
        expect(writes, 0);
      },
    );
  }
}
