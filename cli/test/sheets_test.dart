import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import '../../lib/models/transaction.dart';
import '../../lib/models/other_asset.dart';
import '../../lib/services/sheets_service.dart';
import '../src/ledger.dart';
import 'ledger_test.dart' show buy;

class FakeSheets {
  final rows = <List<String>>[];
  int appends = 0;
  bool failAfterAppend = false;
  final writes = <http.Request>[];
  final settings = <List<String>>[
    ['accounts', '["본석"]'],
    ['brokers', '["토스증권"]'],
    ['exchange_rate', '1360'],
  ];
  http.Response json(Object v, [int status = 200]) => http.Response(
    jsonEncode(v),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final repo = SheetsService(
    spreadsheetId: 'fake-sheet',
    getAuthHeaders: () async => {},
    client: MockClient((req) async {
      final path = Uri.decodeComponent(req.url.path);
      if (req.method != 'GET') writes.add(req);
      if (path.endsWith('/values:batchGet'))
        return json({
          'valueRanges': [
            {
              'values': [Transaction.sheetHeaders, ...rows],
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
                ['SPCX', 'US', 'SPCX', '145', 'SpaceX', '0', '145', 'USD'],
              ],
            },
            {
              'values': [OtherAsset.sheetHeaders],
            },
            {'values': settings},
          ],
        });
      if (path.endsWith('/fake-sheet'))
        return json({
          'properties': {'title': 'Fake'},
          'sheets': [
            for (final name in [
              'Transactions',
              'Prices',
              'OtherAssets',
              'Settings',
            ])
              {
                'properties': {'title': name, 'sheetId': 1},
              },
          ],
        });
      if (path.endsWith('/values:batchUpdate')) return json({});
      if (path.contains('/values/Settings!')) return json({'values': settings});
      if (path.contains('/values/Prices!'))
        return json({
          'values': [
            ['SPCX', 'US'],
          ],
        });
      if (path.contains('/values/Transactions!')) {
        if (path.endsWith(':append')) {
          appends++;
          rows.addAll(
            (jsonDecode(req.body)['values'] as List).map(
              (r) => List<String>.from(r as List),
            ),
          );
          return failAfterAppend ? json({}, 503) : json({});
        }
        if (req.method == 'PUT') {
          final idx =
              int.parse(RegExp(r'!A(\d+)').firstMatch(path)!.group(1)!) - 2;
          rows[idx] = List<String>.from(jsonDecode(req.body)['values'][0]);
          return json({});
        }
        final match = RegExp(r'!A(\d+):Z(\d+)$').firstMatch(path);
        return json({
          'values': match == null
              ? rows
              : [rows[int.parse(match.group(1)!) - 2]],
        });
      }
      throw StateError('Unexpected ${req.method} $path');
    }),
  );
}

void main() {
  test('preview GET only; apply RAW and verify persistence', () async {
    final fake = FakeSheets();
    addTearDown(fake.repo.close);
    final p = plan(await fake.repo.loadAll(), 'trade', 'add', {
      ...buy(),
      'memo': '=IMPORTDATA("example")',
    });
    expect(fake.writes, isEmpty);
    await applyChange(fake.repo, p);
    expect(fake.appends, 1);
    final append = fake.writes.singleWhere(
      (r) => r.url.path.endsWith(':append'),
    );
    expect(append.url.queryParameters['valueInputOption'], 'RAW');
    expect(fake.rows.single[13], '12:38');
    final again = plan(await fake.repo.loadAll(), 'trade', 'add', buy());
    expect(again.action, 'noop');
    await applyChange(fake.repo, again);
    expect(fake.appends, 1);
  });
  test('concurrent ledger change aborts before any write', () async {
    final fake = FakeSheets();
    addTearDown(fake.repo.close);
    final p = plan(await fake.repo.loadAll(), 'trade', 'add', buy());
    fake.rows.add([...p.after!]..[0] = 'another');
    await expectLater(applyChange(fake.repo, p), throwsStateError);
    expect(fake.writes, isEmpty);
  });
  test('ambiguous response never retries append; recovery is noop', () async {
    final fake = FakeSheets()..failAfterAppend = true;
    addTearDown(fake.repo.close);
    final p = plan(await fake.repo.loadAll(), 'trade', 'add', buy());
    await expectLater(
      applyChange(fake.repo, p),
      throwsA(isA<SheetsApiException>()),
    );
    expect(fake.appends, 1);
    expect(
      plan(await fake.repo.loadAll(), 'trade', 'add', buy()).action,
      'noop',
    );
  });
  test('update then delete verifies saved rows', () async {
    final fake = FakeSheets();
    addTearDown(fake.repo.close);
    final first = plan(await fake.repo.loadAll(), 'trade', 'add', buy());
    await applyChange(fake.repo, first);
    final update = plan(await fake.repo.loadAll(), 'trade', 'update', {
      'id': first.id,
      'price': '150',
    });
    await applyChange(fake.repo, update);
    expect(fake.rows.single[8], '150.0');
    final deletion = plan(await fake.repo.loadAll(), 'trade', 'delete', {
      'id': first.id,
    });
    await applyChange(fake.repo, deletion);
    expect(fake.rows.single.every((x) => x.isEmpty), true);
  });
}
