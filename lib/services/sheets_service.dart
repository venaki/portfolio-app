import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/other_asset.dart';
import '../models/portfolio_snapshot.dart';
import '../models/stock_quote.dart';
import '../models/transaction.dart';
import 'historical_prices.dart';
import 'portfolio_backup.dart';
import 'sheets_api_client.dart';
export 'historical_prices.dart';
export 'sheets_api_client.dart' show SheetsApiException;

typedef PortfolioData = ({
  List<Transaction> transactions,
  List<StockQuote> quotes,
  double exchangeRate,
  List<OtherAsset> otherAssets,
  AppSettings settings,
});
typedef PriceData = ({List<StockQuote> quotes, double exchangeRate});

/// A connected instance owns one spreadsheet for its entire lifetime.
class SheetsService {
  static const _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const _priceHeaders = [
    'ticker',
    'market',
    'googlefinance_key',
    'price',
    'name',
    'changepct',
    'closeyest',
    'currency',
  ];
  static const _historicalHeaders = ['date', 'ticker', 'price'];
  final SheetsApiClient _api;
  String? _spreadsheetId;
  String? spreadsheetName;
  final List<String> dataIssues = [];
  final List<String> snapshotIssues = [];
  bool exchangeRateValid = false;
  String? historyDirtyFrom;
  bool _schemaReady = false;
  Map<String, Map<String, dynamic>> _sheetProperties = {};
  final Map<String, List<String>> _loadedRows = {};
  Future<void> _writeTail = Future.value();

  SheetsService({
    required Future<Map<String, String>> Function() getAuthHeaders,
    http.Client? client,
    String? spreadsheetId,
    void Function()? onUnauthorized,
  }) : _api = SheetsApiClient(
         getAuthHeaders: getAuthHeaders,
         client: client,
         onUnauthorized: onUnauthorized,
       ),
       _spreadsheetId = spreadsheetId;
  SheetsService._session(this._api, this._spreadsheetId);
  String? get spreadsheetId => _spreadsheetId;
  SheetsService forSpreadsheet(String id) {
    _validateId(id);
    return SheetsService._session(_api, id);
  }

  void setSpreadsheetId(String id) {
    _validateId(id);
    if (_spreadsheetId != null && _spreadsheetId != id) {
      throw StateError('새 시트에는 별도의 저장소 연결이 필요합니다.');
    }
    _spreadsheetId = id;
  }

  void close() => _api.close();
  static void _validateId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('올바른 스프레드시트 ID를 입력해 주세요.');
    }
  }

  String get _id => _spreadsheetId ?? (throw StateError('스프레드시트를 먼저 연결해 주세요.'));
  Uri _url(String suffix, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/$_id$suffix').replace(queryParameters: query);
  Future<T> _write<T>(Future<T> Function() action) {
    final result = _writeTail.then((_) => action());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<String> createSpreadsheet() async {
    final data = await _api.request(
      'POST',
      Uri.parse(_baseUrl),
      body: {
        'properties': {'title': 'Portfolio DB'},
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
              'properties': {'title': title},
            },
        ],
      },
    );
    final id = data['spreadsheetId'] as String?;
    if (id == null) throw const SheetsApiException('새 시트의 ID를 확인할 수 없습니다.');
    final session = forSpreadsheet(id);
    await session._batchValues([
      _values('Transactions!A1', [Transaction.sheetHeaders]),
      _values('Prices!A1', [_priceHeaders]),
      _values('OtherAssets!A1', [OtherAsset.sheetHeaders]),
      _values(
        'Settings!A1',
        const AppSettings()
            .toSheetRows()
            .where((r) => r.first != 'exchange_rate')
            .toList(),
      ),
      _values('Snapshots!A1', [PortfolioSnapshot.sheetHeaders]),
      _values('HistoricalPrices!A1', [_historicalHeaders]),
    ]);
    await session.addPriceRow('USDKRW', 'FX', 'KRW');
    await session._saveSettingValues(
      {'exchange_rate': '=GOOGLEFINANCE("CURRENCY:USDKRW")'},
      formulaKeys: {'exchange_rate'},
    );
    return id;
  }

  Future<void> _inspect() async {
    final meta = await _api.request(
      'GET',
      _url('', {'fields': 'properties.title,sheets.properties'}),
    );
    spreadsheetName = (meta['properties'] as Map?)?['title'] as String?;
    _sheetProperties = {
      for (final sheet in (meta['sheets'] as List? ?? []))
        sheet['properties']['title'] as String: Map<String, dynamic>.from(
          sheet['properties'] as Map,
        ),
    };
    for (final name in ['Transactions', 'Prices', 'OtherAssets', 'Settings']) {
      if (!_sheetProperties.containsKey(name)) {
        throw FormatException('Portfolio 형식의 시트가 아닙니다: $name 시트가 없습니다.');
      }
    }
  }

  Future<void> _ensureSchema() async {
    if (_schemaReady) return;
    await _inspect();
    for (final entry in {
      'Snapshots': PortfolioSnapshot.sheetHeaders,
      'HistoricalPrices': _historicalHeaders,
    }.entries) {
      if (!_sheetProperties.containsKey(entry.key)) {
        final result = await _api.request(
          'POST',
          _url(':batchUpdate'),
          body: {
            'requests': [
              {
                'addSheet': {
                  'properties': {'title': entry.key},
                },
              },
            ],
          },
        );
        final props = result['replies']?[0]?['addSheet']?['properties'];
        if (props is Map) {
          _sheetProperties[entry.key] = Map<String, dynamic>.from(props);
        }
        await _putValues('${entry.key}!A1', [entry.value]);
      }
    }
    _schemaReady = true;
  }

  Future<PortfolioData> loadAll() async {
    final ranges = await _batchGet([
      'Transactions!A1:Z',
      'Prices!A1:H',
      'OtherAssets!A1:Z',
      'Settings!A1:B',
    ]);
    dataIssues.clear();
    _loadedRows.clear();
    _validateHeader(
      ranges[0],
      Transaction.sheetHeaders,
      'Transactions',
      minColumns: 11,
    );
    _validateHeader(ranges[1], _priceHeaders, 'Prices');
    _validateHeader(
      ranges[2],
      OtherAsset.sheetHeaders,
      'OtherAssets',
      minColumns: 7,
    );
    final transactions = _parseRows(
      ranges[0].skip(1),
      'Transactions',
      Transaction.fromSheetRow,
    );
    final assets = _parseRows(
      ranges[2].skip(1),
      'OtherAssets',
      OtherAsset.fromSheetRow,
    );
    final settings = AppSettings.fromSheetRows(ranges[3]);
    historyDirtyFrom = _setting(ranges[3], 'history_dirty_from');
    final prices = _parsePrices(ranges[1].skip(1), settings);
    await _inspect();
    return (
      transactions: transactions,
      quotes: prices.quotes,
      exchangeRate: prices.exchangeRate,
      otherAssets: assets,
      settings: settings,
    );
  }

  static void _validateHeader(
    List<List<String>> rows,
    List<String> expected,
    String sheet, {
    int? minColumns,
  }) {
    final count = minColumns ?? expected.length;
    if (rows.isEmpty || rows.first.length < count) {
      throw FormatException('$sheet 헤더를 확인해 주세요.');
    }
    final present = rows.first.length < expected.length
        ? rows.first.length
        : expected.length;
    for (var i = 0; i < present; i++) {
      if (rows.first[i].trim() != expected[i]) {
        throw FormatException('$sheet ${i + 1}번째 열은 ${expected[i]}이어야 합니다.');
      }
    }
  }

  List<T> _parseRows<T>(
    Iterable<List<String>> rows,
    String sheet,
    T Function(List<String>) parse, {
    List<String>? issues,
  }) {
    final errors = issues ?? dataIssues;
    final result = <T>[];
    final seen = <String>{};
    var rowNumber = 1;
    for (final row in rows) {
      rowNumber++;
      if (row.every((c) => c.trim().isEmpty)) continue;
      try {
        if (row.isEmpty || row.first.isEmpty || !seen.add(row.first)) {
          throw const FormatException('ID가 없거나 중복되어 있습니다.');
        }
        result.add(parse(row));
        _loadedRows['$sheet/${row.first}'] = [...row];
      } on FormatException catch (e) {
        errors.add('$sheet $rowNumber행: ${e.message}');
      } on RangeError {
        errors.add('$sheet $rowNumber행: 필수 열이 누락되었습니다.');
      }
    }
    return result;
  }

  PriceData _parsePrices(Iterable<List<String>> rows, AppSettings settings) {
    final quotes = <StockQuote>[];
    var rate = settings.exchangeRate;
    for (final raw in rows) {
      if (raw.every((c) => c.isEmpty)) continue;
      final row = _pad(raw, 8);
      if (row[1] == 'FX') {
        rate ??= double.tryParse(row[3]);
      } else {
        quotes.add(StockQuote.fromSheetRow(row));
      }
    }
    exchangeRateValid = rate != null && rate.isFinite && rate > 0;
    return (quotes: quotes, exchangeRate: exchangeRateValid ? rate! : 0);
  }

  Future<PriceData> loadPrices() async {
    final ranges = await _batchGet(['Prices!A2:H', 'Settings!A1:B']);
    return _parsePrices(ranges[0], AppSettings.fromSheetRows(ranges[1]));
  }

  /// Refresh never intentionally edits or breaks source formulas.
  Future<PriceData> forceRefreshPrices({int waitSeconds = 3}) => loadPrices();

  Future<void> addTransaction(Transaction tx) => _write(() async {
    Transaction.fromSheetRow(tx.toSheetRow());
    await _appendUnique('Transactions', tx.id, tx.toSheetRow());
  });
  Future<void> updateTransaction(Transaction tx) => _write(() async {
    Transaction.fromSheetRow(tx.toSheetRow());
    await _updateRecord('Transactions', tx.id, tx.toSheetRow());
  });
  Future<void> deleteTransaction(String id) =>
      _write(() => _deleteRecord('Transactions', id));
  Future<void> addOtherAsset(OtherAsset asset) => _write(() async {
    OtherAsset.fromSheetRow(asset.toSheetRow());
    await _appendUnique('OtherAssets', asset.id, asset.toSheetRow());
  });
  Future<void> updateOtherAsset(OtherAsset asset) => _write(() async {
    OtherAsset.fromSheetRow(asset.toSheetRow());
    await _updateRecord('OtherAssets', asset.id, asset.toSheetRow());
  });
  Future<void> deleteOtherAsset(String id) =>
      _write(() => _deleteRecord('OtherAssets', id));
  Future<void> _appendUnique(String sheet, String id, List<String> row) async {
    final rows = await _getValues('$sheet!A2:Z');
    final existing = rows.where((r) => r.isNotEmpty && r.first == id).toList();
    if (existing.isNotEmpty) {
      if (existing.length == 1 && _sameRow(existing.single, row)) {
        _loadedRows['$sheet/$id'] = [...row];
        return;
      }
      throw const SheetsApiException('같은 ID의 다른 데이터가 있습니다. 다시 불러와 주세요.');
    }
    await _appendValues('$sheet!A:Z', [row]);
    _loadedRows['$sheet/$id'] = [...row];
  }

  Future<({int index, List<String> row})> _findRecord(
    String sheet,
    String id,
  ) async {
    final rows = await _getValues('$sheet!A2:Z');
    final matches = rows.indexed
        .where((e) => e.$2.isNotEmpty && e.$2.first == id)
        .toList();
    if (matches.length != 1) {
      throw const SheetsApiException('대상 데이터가 삭제되었거나 중복되었습니다. 다시 불러와 주세요.');
    }
    final entry = matches.single, expected = _loadedRows['$sheet/$id'];
    if (expected != null && !_sameRow(expected, entry.$2)) {
      throw const SheetsApiException('다른 곳에서 수정한 데이터입니다. 다시 불러온 뒤 수정해 주세요.');
    }
    return (index: entry.$1, row: entry.$2);
  }

  Future<void> _updateRecord(String sheet, String id, List<String> row) async {
    final found = await _findRecord(sheet, id);
    final range = '$sheet!A${found.index + 2}:Z${found.index + 2}';
    final latest = await _getValues(range);
    if (latest.length != 1 || !_sameRow(latest.single, found.row)) {
      throw const SheetsApiException('행 위치가 변경되었습니다. 다시 불러와 주세요.');
    }
    await _putValues(range, [_pad(row, 26)]);
    _loadedRows['$sheet/$id'] = [...row];
  }

  Future<void> _deleteRecord(String sheet, String id) async {
    final found = await _findRecord(sheet, id);
    final range = '$sheet!A${found.index + 2}:Z${found.index + 2}';
    final latest = await _getValues(range);
    if (latest.length != 1 || !_sameRow(latest.single, found.row)) {
      throw const SheetsApiException('행 위치가 변경되었습니다. 다시 불러와 주세요.');
    }
    // A tombstone does not shift other clients' row numbers.
    await _putValues(range, [List.filled(26, '')]);
    _loadedRows.remove('$sheet/$id');
  }

  Future<int> findRowById(String sheetName, String id) async =>
      (await _findRecord(sheetName, id)).index;

  Future<void> addPriceRow(String ticker, String market, String currency) =>
      _write(() async {
        final row = _priceRow(ticker, market, currency);
        final existing = await _getValues('Prices!A2:H');
        if (existing.any(
          (r) =>
              r.length >= 2 &&
              _normalizeTicker(r[0], r[1]) == ticker &&
              r[1] == market,
        )) {
          return;
        }
        await _appendValues('Prices!A:H', [row], userEntered: true);
      });
  static String _normalizeTicker(String ticker, String market) =>
      (market == 'KRX' || market == 'KOSDAQ') &&
          RegExp(r'^\d+$').hasMatch(ticker)
      ? ticker.padLeft(6, '0')
      : ticker;
  static List<String> _priceRow(String ticker, String market, String currency) {
    final korean = market == 'KRX' || market == 'KOSDAQ';
    if ((korean && !RegExp(r'^\d{6}$').hasMatch(ticker)) ||
        (!korean && !RegExp(r'^[A-Z0-9.^:=-]{1,30}$').hasMatch(ticker))) {
      throw const FormatException('종목 코드 형식이 올바르지 않습니다.');
    }
    if (!['US', 'KRX', 'KOSDAQ', 'FX'].contains(market)) {
      throw const FormatException('지원하지 않는 시장입니다.');
    }
    if (market == 'FX') {
      return [
        'USDKRW',
        'FX',
        'CURRENCY:USDKRW',
        '=GOOGLEFINANCE("CURRENCY:USDKRW")',
        '',
        '',
        '',
        'KRW',
      ];
    }
    final key = korean ? '$market:$ticker' : ticker;
    String formula(String attribute) => '=GOOGLEFINANCE("$key","$attribute")';
    return [
      korean ? "'$ticker" : ticker,
      market,
      key,
      formula('price'),
      formula('name'),
      formula('changepct'),
      formula('closeyest'),
      currency,
    ];
  }

  Future<void> saveSettings(AppSettings settings) => _write(() async {
    final rows = settings.toSheetRows();
    AppSettings.fromSheetRows(rows);
    await _saveSettingValues({
      for (final r in rows)
        if (r.first != 'exchange_rate') r[0]: r[1],
    });
  });
  Future<void> setHistoryDirtyFrom(String? date) => _write(() async {
    await _saveSettingValues({'history_dirty_from': date ?? ''});
    historyDirtyFrom = date;
  });
  Future<void> _saveSettingValues(
    Map<String, String> values, {
    Set<String> formulaKeys = const {},
  }) async {
    final rows = await _getValues('Settings!A1:B');
    AppSettings.fromSheetRows(rows);
    final updates = <Map<String, dynamic>>[], appends = <List<String>>[];
    for (final entry in values.entries) {
      final i = rows.indexWhere((r) => r.isNotEmpty && r.first == entry.key);
      if (i < 0) {
        appends.add([entry.key, entry.value]);
      } else {
        updates.add(
          _values('Settings!A${i + 1}:B${i + 1}', [
            [entry.key, entry.value],
          ]),
        );
      }
    }
    if (appends.isNotEmpty) {
      updates.add(
        _values(
          'Settings!A${rows.length + 1}:B${rows.length + appends.length}',
          appends,
        ),
      );
    }
    if (updates.isNotEmpty) await _batchValues(updates);
    // Only application-owned formulas use USER_ENTERED; names always use RAW.
    if (formulaKeys.isNotEmpty) {
      final current = await _getValues('Settings!A1:B');
      await _batchValues([
        for (final key in formulaKeys)
          _values(
            'Settings!B${current.indexWhere((r) => r.isNotEmpty && r.first == key) + 1}',
            [
              [values[key]!],
            ],
          ),
      ], userEntered: true);
    }
  }

  Future<List<PortfolioSnapshot>> loadSnapshots() async {
    await _ensureSchema();
    snapshotIssues.clear();
    final rows = await _getValues('Snapshots!A1:L');
    _validateHeader(
      rows,
      PortfolioSnapshot.sheetHeaders,
      'Snapshots',
      minColumns: 9,
    );
    final snapshots = _parseRows(
      rows.skip(1).toList(),
      'Snapshots',
      PortfolioSnapshot.fromSheetRow,
      issues: snapshotIssues,
    );
    final byDate = <String, PortfolioSnapshot>{};
    for (final snapshot in snapshots) {
      final previous = byDate[snapshot.date];
      if (previous == null ||
          (previous.source != 'live' && snapshot.source == 'live') ||
          (previous.source == snapshot.source &&
              snapshot.createdAt.compareTo(previous.createdAt) > 0)) {
        byDate[snapshot.date] = snapshot;
      }
    }
    return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> upsertSnapshot(PortfolioSnapshot snapshot) =>
      upsertSnapshots([snapshot]);
  Future<void> upsertSnapshots(List<PortfolioSnapshot> snapshots) =>
      _write(() async {
        if (snapshots.isEmpty) return;
        await _ensureSchema();
        final existing = await _getValues('Snapshots!A2:L');
        final updates = <Map<String, dynamic>>[], appends = <List<String>>[];
        for (final snapshot in snapshots) {
          PortfolioSnapshot.fromSheetRow(snapshot.toSheetRow());
          final matches = existing.indexed
              .where((r) => r.$2.length > 1 && r.$2[1] == snapshot.date)
              .toList();
          if (snapshot.source != 'live' &&
              matches.any((r) => r.$2.length > 9 && r.$2[9] == 'live')) {
            continue;
          }
          if (matches.isEmpty) {
            appends.add(snapshot.toSheetRow());
          } else {
            updates.add(
              _values(
                'Snapshots!A${matches.first.$1 + 2}:L${matches.first.$1 + 2}',
                [snapshot.toSheetRow()],
              ),
            );
            for (final duplicate in matches.skip(1)) {
              updates.add(
                _values('Snapshots!A${duplicate.$1 + 2}:L${duplicate.$1 + 2}', [
                  List.filled(12, ''),
                ]),
              );
            }
          }
        }
        if (updates.isNotEmpty) await _batchValues(updates);
        if (appends.isNotEmpty) await _appendValues('Snapshots!A:L', appends);
      });
  Future<HistoricalPriceImport> loadHistoricalPrices() async {
    await _ensureSchema();
    final rows = await _getValues('HistoricalPrices!A1:C');
    _validateHeader(
      rows,
      _historicalHeaders,
      'HistoricalPrices',
      minColumns: 3,
    );
    return HistoricalPriceImport.fromRows(rows.skip(1).toList());
  }

  Future<void> saveHistoricalPrices(HistoricalPriceImport imported) =>
      _write(() async {
        final merged = (await loadHistoricalPrices()).merge(imported);
        await _replaceSheets({
          'HistoricalPrices': [_historicalHeaders, ...merged.toRows()],
        });
      });

  /// Historical GOOGLEFINANCE arrays cannot be read by the Sheets API.
  Future<BackfillPriceData> loadBackfillPriceData({
    required List<BackfillPriceRequest> requests,
    required DateTime start,
    required DateTime end,
    int waitSeconds = 20,
  }) async => (await loadHistoricalPrices()).toBackfillData(requests);
  Future<PortfolioBackup> createBackup() async {
    final data = await loadAll(), snapshots = await loadSnapshots();
    if (dataIssues.isNotEmpty || snapshotIssues.isNotEmpty) {
      throw const FormatException(
        '잘못된 행이 있어 완전한 백업을 만들 수 없습니다. 시트 원본을 먼저 내려받아 주세요.',
      );
    }
    final rawSettings = await _getValues(
      'Settings!A1:B',
      renderOption: 'FORMULA',
    );
    final knownKeys = data.settings.toSheetRows().map((r) => r.first).toSet();
    final backup = PortfolioBackup(
      transactions: data.transactions,
      otherAssets: data.otherAssets,
      settings: data.settings,
      snapshots: snapshots,
      historicalPrices: await loadHistoricalPrices(),
      exchangeRateSource:
          _setting(rawSettings, 'exchange_rate') ??
          '=GOOGLEFINANCE("CURRENCY:USDKRW")',
      extraSettings: {
        for (final row in rawSettings)
          if (row.length >= 2 && !knownKeys.contains(row.first))
            row.first: row[1],
      },
    );
    backup.validate();
    return backup;
  }

  Future<void> restoreBackup(PortfolioBackup backup) => _write(() async {
    backup.validate();
    await _ensureSchema();
    final tickers = <String, Transaction>{};
    for (final tx in backup.transactions) {
      tickers['${tx.market.name}/${tx.ticker}'] = tx;
    }
    await _replaceSheets({
      'Transactions': [
        Transaction.sheetHeaders,
        ...backup.transactions.map((t) => t.toSheetRow()),
      ],
      'OtherAssets': [
        OtherAsset.sheetHeaders,
        ...backup.otherAssets.map((a) => a.toSheetRow()),
      ],
      'Settings': backup.settingsRows,
      'Snapshots': [
        PortfolioSnapshot.sheetHeaders,
        ...backup.snapshots.map((s) => s.toSheetRow()),
      ],
      'HistoricalPrices': [
        _historicalHeaders,
        ...backup.historicalPrices.toRows(),
      ],
      'Prices': [
        _priceHeaders,
        _priceRow('USDKRW', 'FX', 'KRW'),
        for (final tx in tickers.values)
          _priceRow(
            tx.ticker,
            tx.market.toSheetValue(),
            tx.currency == Currency.krw ? 'KRW' : 'USD',
          ),
      ],
    }, formulas: true);
    _loadedRows.clear();
  });

  /// One atomic Sheets batch; no preliminary clear can leave a partial restore.
  Future<void> _replaceSheets(
    Map<String, List<List<String>>> sheets, {
    bool formulas = false,
  }) async {
    await _inspect();
    final requests = <Map<String, dynamic>>[];
    for (final entry in sheets.entries) {
      final props = _sheetProperties[entry.key];
      if (props == null) throw FormatException('${entry.key} 시트를 찾을 수 없습니다.');
      final sheetId = props['sheetId'],
          grid = props['gridProperties'] as Map? ?? {};
      final oldRows = (grid['rowCount'] as int?) ?? 1000,
          oldCols = (grid['columnCount'] as int?) ?? 26;
      final width = entry.value.fold<int>(
            1,
            (v, r) => r.length > v ? r.length : v,
          ),
          height = entry.value.isEmpty ? 1 : entry.value.length;
      if (height > oldRows || width > oldCols) {
        requests.add({
          'updateSheetProperties': {
            'properties': {
              'sheetId': sheetId,
              'gridProperties': {
                'rowCount': height > oldRows ? height : oldRows,
                'columnCount': width > oldCols ? width : oldCols,
              },
            },
            'fields': 'gridProperties(rowCount,columnCount)',
          },
        });
      }
      requests.add({
        'updateCells': {
          'range': {
            'sheetId': sheetId,
            'startRowIndex': 0,
            'startColumnIndex': 0,
            'endRowIndex': height > oldRows ? height : oldRows,
            'endColumnIndex': width,
          },
          'rows': [
            for (final row in entry.value)
              {
                'values': [
                  for (var col = 0; col < row.length; col++)
                    {
                      'userEnteredValue': _cellValue(
                        entry.key,
                        row,
                        col,
                        formulas,
                      ),
                    },
                ],
              },
          ],
          'fields': 'userEnteredValue',
        },
      });
    }
    await _api.request(
      'POST',
      _url(':batchUpdate'),
      body: {'requests': requests},
    );
  }

  static Map<String, String> _cellValue(
    String sheet,
    List<String> row,
    int col,
    bool formulas,
  ) {
    final value = row[col];
    final formula =
        formulas &&
        value.startsWith('=') &&
        ((sheet == 'Prices' && col >= 3 && col <= 6) ||
            (sheet == 'Settings' && row.first == 'exchange_rate' && col == 1));
    return {
      formula ? 'formulaValue' : 'stringValue':
          sheet == 'Prices' && col == 0 && value.startsWith("'")
          ? value.substring(1)
          : value,
    };
  }

  Future<List<List<List<String>>>> _batchGet(List<String> ranges) async {
    final query =
        'valueRenderOption=UNFORMATTED_VALUE&${ranges.map((r) => 'ranges=${Uri.encodeComponent(r)}').join('&')}';
    final result = await _api.request(
      'GET',
      Uri.parse('$_baseUrl/$_id/values:batchGet?$query'),
    );
    final values = result['valueRanges'] as List?;
    if (values == null || values.length != ranges.length) {
      throw const SheetsApiException('일부 시트의 응답이 누락되었습니다.');
    }
    return values.map((v) => _rows(v as Map)).toList();
  }

  Future<List<List<String>>> _getValues(
    String range, {
    String renderOption = 'UNFORMATTED_VALUE',
  }) async => _rows(
    await _api.request(
      'GET',
      _url('/values/${Uri.encodeComponent(range)}', {
        'valueRenderOption': renderOption,
      }),
    ),
  );
  Future<void> _putValues(String range, List<List<String>> rows) async {
    await _api.request(
      'PUT',
      _url('/values/${Uri.encodeComponent(range)}', {
        'valueInputOption': 'RAW',
      }),
      body: {'values': rows},
    );
  }

  Future<void> _appendValues(
    String range,
    List<List<String>> rows, {
    bool userEntered = false,
  }) async {
    await _api.request(
      'POST',
      _url('/values/${Uri.encodeComponent(range)}:append', {
        'valueInputOption': userEntered ? 'USER_ENTERED' : 'RAW',
      }),
      body: {'values': rows},
    );
  }

  Future<void> _batchValues(
    List<Map<String, dynamic>> values, {
    bool userEntered = false,
  }) async {
    await _api.request(
      'POST',
      _url('/values:batchUpdate'),
      body: {
        'valueInputOption': userEntered ? 'USER_ENTERED' : 'RAW',
        'data': values,
      },
    );
  }

  static Map<String, dynamic> _values(String range, List<List<String>> rows) =>
      {'range': range, 'values': rows};
  static List<List<String>> _rows(Map data) => ((data['values'] as List?) ?? [])
      .map((row) => (row as List).map((cell) => cell.toString()).toList())
      .toList();
  static List<String> _pad(List<String> row, int length) => List.generate(
    row.length > length ? row.length : length,
    (i) => i < row.length ? row[i] : '',
  );
  static bool _sameRow(List<String> a, List<String> b) =>
      jsonEncode(_pad(a, a.length > b.length ? a.length : b.length)) ==
      jsonEncode(_pad(b, a.length > b.length ? a.length : b.length));
  static String? _setting(List<List<String>> rows, String key) {
    for (final row in rows) {
      if (row.length > 1 && row.first == key && row[1].isNotEmpty) {
        return row[1];
      }
    }
    return null;
  }
}
